SET SERVEROUTPUT ON;

--------------------------------------------------------------------------------
-- PACHET: PKG_GESTIUNE_STOC
-- Flux: analiza -> comanda (in memorie) -> receptie (update Produse) -> raport
--------------------------------------------------------------------------------

BEGIN
  EXECUTE IMMEDIATE 'DROP PACKAGE pkg_gestiune_stoc';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
CREATE OR REPLACE PACKAGE pkg_gestiune_stoc AS
  ------------------------------------------------------------------------------
  -- Tipuri complexe: record + nested table + associative array (map)
  ------------------------------------------------------------------------------
  TYPE t_linie_analiza IS RECORD(
    id_produs         Produse.id_produs%TYPE,
    nume_produs       Produse.nume_produs%TYPE,
    unitate_masura    Produse.unitate_masura%TYPE,
    stoc_curent       Produse.cantitate%TYPE,
    necesar_eveniment NUMBER,
    cerere_orizont    NUMBER,
    tinta_stoc        NUMBER,
    deficit           NUMBER,
    recomandare       VARCHAR2(20) -- 'COMANDA' / 'NU_COMANDA'
  );

  TYPE t_lista_analiza IS TABLE OF t_linie_analiza;

  -- o "comandă" in memorie pentru un produs
  TYPE t_comanda_produs IS RECORD(
    id_produs      Produse.id_produs%TYPE,
    nume_produs    Produse.nume_produs%TYPE,
    unitate_masura Produse.unitate_masura%TYPE,
    cantitate      NUMBER, -- cantitatea ce va fi adaugata la stoc la receptie
    id_eveniment   Evenimente.id_eveniment%TYPE,
    data_evt       DATE,
    orizont_zile   NUMBER,
    buffer_pct     NUMBER,
    created_at     TIMESTAMP
  );

  -- map: id_produs -> comanda pending (1 per produs)
  TYPE t_comenzi_map IS TABLE OF t_comanda_produs INDEX BY PLS_INTEGER;

  ------------------------------------------------------------------------------
  -- Functii
  ------------------------------------------------------------------------------
  FUNCTION f_data_eveniment(p_id_eveniment IN NUMBER) RETURN DATE;

  FUNCTION f_cerere_produs_orizont(
    p_id_produs  IN NUMBER,
    p_data_start IN DATE,
    p_data_end   IN DATE
  ) RETURN NUMBER;

  FUNCTION f_analiza_eveniment(
    p_id_eveniment IN NUMBER,
    p_orizont_zile IN NUMBER DEFAULT 0,
    p_buffer_pct   IN NUMBER DEFAULT 0
  ) RETURN t_lista_analiza;

  ------------------------------------------------------------------------------
  -- Proceduri (flux)
  ------------------------------------------------------------------------------
  PROCEDURE p_genereaza_comenzi(
    p_id_eveniment IN NUMBER,
    p_orizont_zile IN NUMBER DEFAULT 0,
    p_buffer_pct   IN NUMBER DEFAULT 0
  );

  PROCEDURE p_raport_eveniment(
    p_id_eveniment IN NUMBER,
    p_orizont_zile IN NUMBER DEFAULT 0,
    p_buffer_pct   IN NUMBER DEFAULT 0
  );

  PROCEDURE p_raport_comenzi_curente;

  -- receptie/anulare per produs
  PROCEDURE p_receptioneaza_comanda_produs(p_id_produs IN NUMBER);
  PROCEDURE p_anuleaza_comanda_produs(p_id_produs IN NUMBER);

  -- utilitare: receptie/anulare pentru toate comenzile pending
  PROCEDURE p_receptioneaza_toate;
  PROCEDURE p_anuleaza_toate;

END pkg_gestiune_stoc;
/
SHOW ERRORS;

CREATE OR REPLACE PACKAGE BODY pkg_gestiune_stoc AS

  -- stare in memorie (pe sesiune): comenzi multiple, cheie = id_produs
  g_comenzi t_comenzi_map;

  PROCEDURE validate_params(p_id_eveniment NUMBER, p_orizont_zile NUMBER, p_buffer_pct NUMBER) IS
  BEGIN
    IF p_id_eveniment IS NULL OR p_orizont_zile IS NULL OR p_buffer_pct IS NULL
       OR p_orizont_zile < 0 OR p_buffer_pct < 0 OR p_buffer_pct > 100 THEN
      RAISE_APPLICATION_ERROR(-20102, 'Parametri invalizi (orizont>=0, buffer 0..100).');
    END IF;
  END;

  FUNCTION f_data_eveniment(p_id_eveniment IN NUMBER) RETURN DATE IS
    v_d DATE;
  BEGIN
    SELECT data_eveniment INTO v_d
    FROM Evenimente
    WHERE id_eveniment = p_id_eveniment;
    RETURN v_d;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20100, 'Eveniment inexistent (id_eveniment='||p_id_eveniment||').');
  END;

  FUNCTION f_cerere_produs_orizont(
    p_id_produs  IN NUMBER,
    p_data_start IN DATE,
    p_data_end   IN DATE
  ) RETURN NUMBER IS
    v_sum NUMBER;
  BEGIN
    SELECT NVL(SUM(ep.cantitate), 0)
    INTO   v_sum
    FROM   Evenimente_Produse ep
    JOIN   Evenimente e ON e.id_eveniment = ep.id_eveniment
    WHERE  ep.id_produs = p_id_produs
      AND  TRUNC(e.data_eveniment) >= TRUNC(p_data_start)
      AND  TRUNC(e.data_eveniment) <= TRUNC(p_data_end);

    RETURN v_sum;
  END;

  FUNCTION f_analiza_eveniment(
    p_id_eveniment IN NUMBER,
    p_orizont_zile IN NUMBER DEFAULT 0,
    p_buffer_pct   IN NUMBER DEFAULT 0
  ) RETURN t_lista_analiza IS
    v_data_evt DATE;
    v_list t_lista_analiza := t_lista_analiza();
    v_cnt NUMBER;
  BEGIN
    validate_params(p_id_eveniment, p_orizont_zile, p_buffer_pct);

    v_data_evt := f_data_eveniment(p_id_eveniment);

    SELECT COUNT(*) INTO v_cnt
    FROM Evenimente_Produse
    WHERE id_eveniment = p_id_eveniment;

    IF v_cnt = 0 THEN
      RAISE_APPLICATION_ERROR(-20101, 'Eveniment fara produse asociate (Evenimente_Produse).');
    END IF;

    SELECT
      p.id_produs,
      p.nume_produs,
      p.unitate_masura,
      p.cantitate AS stoc_curent,
      ep.cantitate AS necesar_eveniment,
      f_cerere_produs_orizont(p.id_produs, v_data_evt, v_data_evt + p_orizont_zile) AS cerere_orizont,
      CAST(NULL AS NUMBER) AS tinta_stoc,
      CAST(NULL AS NUMBER) AS deficit,
      CAST(NULL AS VARCHAR2(20)) AS recomandare
    BULK COLLECT INTO v_list
    FROM Evenimente_Produse ep
    JOIN Produse p ON p.id_produs = ep.id_produs
    WHERE ep.id_eveniment = p_id_eveniment
    ORDER BY p.id_produs;

    FOR i IN 1 .. v_list.COUNT LOOP
      v_list(i).tinta_stoc :=
        CEIL(
          GREATEST(v_list(i).necesar_eveniment, v_list(i).cerere_orizont)
          * (1 + p_buffer_pct/100)
        );

      v_list(i).deficit := v_list(i).tinta_stoc - v_list(i).stoc_curent;

      IF v_list(i).deficit > 0 THEN
        v_list(i).recomandare := 'COMANDA';
      ELSE
        v_list(i).deficit := 0;
        v_list(i).recomandare := 'NU_COMANDA';
      END IF;
    END LOOP;

    RETURN v_list;
  END;

  PROCEDURE p_raport_eveniment(
    p_id_eveniment IN NUMBER,
    p_orizont_zile IN NUMBER DEFAULT 0,
    p_buffer_pct   IN NUMBER DEFAULT 0
  ) IS
    v_list t_lista_analiza;
    v_data DATE;
  BEGIN
    v_data := f_data_eveniment(p_id_eveniment);
    v_list := f_analiza_eveniment(p_id_eveniment, p_orizont_zile, p_buffer_pct);

    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('RAPORT STOC - Eveniment #'||p_id_eveniment||
                         ' | Data='||TO_CHAR(v_data,'YYYY-MM-DD')||
                         ' | Orizont='||p_orizont_zile||' | Buffer='||p_buffer_pct||'%');
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');

    FOR i IN 1 .. v_list.COUNT LOOP
      DBMS_OUTPUT.PUT_LINE(
        'Produs #'||v_list(i).id_produs||' '||RPAD(v_list(i).nume_produs, 20)||
        ' stoc='||TO_CHAR(v_list(i).stoc_curent)||
        ' necesar_evt='||TO_CHAR(v_list(i).necesar_eveniment)||
        ' cerere_oriz='||TO_CHAR(v_list(i).cerere_orizont)||
        ' tinta='||TO_CHAR(v_list(i).tinta_stoc)||
        ' deficit='||TO_CHAR(v_list(i).deficit)||
        ' -> '||v_list(i).recomandare
      );
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('============================================================');
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('[RAPORT] '||SQLERRM);
  END;

  PROCEDURE p_genereaza_comenzi(
    p_id_eveniment IN NUMBER,
    p_orizont_zile IN NUMBER DEFAULT 0,
    p_buffer_pct   IN NUMBER DEFAULT 0
  ) IS
    v_list t_lista_analiza;
    v_data_evt DATE;
    v_has_deficit BOOLEAN := FALSE;
    v_nr_create PLS_INTEGER := 0;
    v_nr_ignorate PLS_INTEGER := 0;
  BEGIN
    validate_params(p_id_eveniment, p_orizont_zile, p_buffer_pct);
  
    v_data_evt := f_data_eveniment(p_id_eveniment);
    v_list := f_analiza_eveniment(p_id_eveniment, p_orizont_zile, p_buffer_pct);
  
    -- daca nu exista niciun deficit deloc -> comanda inutila
    FOR i IN 1 .. v_list.COUNT LOOP
      IF v_list(i).deficit > 0 THEN
        v_has_deficit := TRUE;
        EXIT;
      END IF;
    END LOOP;
  
    IF NOT v_has_deficit THEN
      RAISE_APPLICATION_ERROR(-20104, 'Stoc suficient raportat la necesar/orizont. Comanda inutila.');
    END IF;
  
    -- Adaugam comenzi doar pentru produsele fara comanda pending; restul se ignora (mesaj)
    FOR i IN 1 .. v_list.COUNT LOOP
      IF v_list(i).deficit > 0 THEN
  
        IF g_comenzi.EXISTS(v_list(i).id_produs) THEN
          v_nr_ignorate := v_nr_ignorate + 1;
          DBMS_OUTPUT.PUT_LINE(
            '[INFO] Produs #'||v_list(i).id_produs||' ('||v_list(i).nume_produs||') '||
            'are deja comanda pending. Pe analiza curenta (orizont='||p_orizont_zile||
            ', buffer='||p_buffer_pct||'%) deficit='||v_list(i).deficit||' -> IGNORAT.'
          );
        ELSE
          g_comenzi(v_list(i).id_produs).id_produs      := v_list(i).id_produs;
          g_comenzi(v_list(i).id_produs).nume_produs    := v_list(i).nume_produs;
          g_comenzi(v_list(i).id_produs).unitate_masura := v_list(i).unitate_masura;
          g_comenzi(v_list(i).id_produs).cantitate      := v_list(i).deficit;
          g_comenzi(v_list(i).id_produs).id_eveniment   := p_id_eveniment;
          g_comenzi(v_list(i).id_produs).data_evt       := v_data_evt;
          g_comenzi(v_list(i).id_produs).orizont_zile   := p_orizont_zile;
          g_comenzi(v_list(i).id_produs).buffer_pct     := p_buffer_pct;
          g_comenzi(v_list(i).id_produs).created_at     := SYSTIMESTAMP;
          v_nr_create := v_nr_create + 1;
        END IF;
  
      END IF;
    END LOOP;
  
    IF v_nr_create = 0 THEN
      DBMS_OUTPUT.PUT_LINE(
        '[COMENZI] Nu s-a adaugat nicio comanda noua pentru eveniment #'||p_id_eveniment||
        '. Produse cu deficit ignorate (aveau deja comanda): '||v_nr_ignorate||'.'
      );
      -- fluxul e ok, doar nu e nimic de adaugat
      RETURN;
    END IF;
  
    DBMS_OUTPUT.PUT_LINE(
      '[COMENZI] Adaugate '||v_nr_create||' comenzi noi in memorie pentru eveniment #'||p_id_eveniment||
      ' (orizont='||p_orizont_zile||', buffer='||p_buffer_pct||'%). '||
      'Ignorate (deja pending): '||v_nr_ignorate||'.'
    );
  
    p_raport_comenzi_curente;
  
  END;

  PROCEDURE p_raport_comenzi_curente IS
    k PLS_INTEGER;
    v_cnt PLS_INTEGER := 0;
  BEGIN
    IF g_comenzi.COUNT = 0 THEN
      DBMS_OUTPUT.PUT_LINE('[COMENZI] (nu exista comenzi pending in memorie)');
      RETURN;
    END IF;

    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('COMENZI PENDING (1 / produs): '||g_comenzi.COUNT);
    k := g_comenzi.FIRST;
    WHILE k IS NOT NULL LOOP
      v_cnt := v_cnt + 1;
      DBMS_OUTPUT.PUT_LINE(
        '  ['||v_cnt||'] Produs #'||g_comenzi(k).id_produs||' '||RPAD(g_comenzi(k).nume_produs, 20)||
        ' cant='||TO_CHAR(g_comenzi(k).cantitate)||' '||g_comenzi(k).unitate_masura||
        ' | eveniment='||g_comenzi(k).id_eveniment||
        ' | data_evt='||TO_CHAR(g_comenzi(k).data_evt,'YYYY-MM-DD')||
        ' | orizont='||g_comenzi(k).orizont_zile||' | buffer='||g_comenzi(k).buffer_pct||'%'
      );
      k := g_comenzi.NEXT(k);
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
  END;

  PROCEDURE p_receptioneaza_comanda_produs(p_id_produs IN NUMBER) IS
    v_q NUMBER;
    v_rows NUMBER;
  BEGIN
    IF p_id_produs IS NULL THEN
      RAISE_APPLICATION_ERROR(-20102, 'Parametru invalid: id_produs NULL.');
    END IF;

    IF NOT g_comenzi.EXISTS(p_id_produs) THEN
      RAISE_APPLICATION_ERROR(-20105, 'Nu exista comanda pending in memorie pentru produs #'||p_id_produs||'.');
    END IF;

    v_q := g_comenzi(p_id_produs).cantitate;

    UPDATE Produse
    SET cantitate = cantitate + v_q
    WHERE id_produs = p_id_produs;

    v_rows := SQL%ROWCOUNT;
    IF v_rows = 0 THEN
      RAISE_APPLICATION_ERROR(-20110, 'Produs inexistent in tabela Produse (id_produs='||p_id_produs||').');
    END IF;

    DBMS_OUTPUT.PUT_LINE('[RECEPTIE] Produs #'||p_id_produs||' + '||v_q||
                         ' (eveniment='||g_comenzi(p_id_produs).id_eveniment||'). Stoc actualizat.');

    g_comenzi.DELETE(p_id_produs);
  END;

  PROCEDURE p_anuleaza_comanda_produs(p_id_produs IN NUMBER) IS
  BEGIN
    IF p_id_produs IS NULL THEN
      RAISE_APPLICATION_ERROR(-20102, 'Parametru invalid: id_produs NULL.');
    END IF;

    IF g_comenzi.EXISTS(p_id_produs) THEN
      DBMS_OUTPUT.PUT_LINE('[ANULARE] S-a anulat comanda pending pentru produs #'||p_id_produs||
                           ' (eveniment='||g_comenzi(p_id_produs).id_eveniment||').');
      g_comenzi.DELETE(p_id_produs);
    ELSE
      DBMS_OUTPUT.PUT_LINE('[ANULARE] Nu exista comanda pending pentru produs #'||p_id_produs||'.');
    END IF;
  END;

  PROCEDURE p_receptioneaza_toate IS
    k PLS_INTEGER;
  BEGIN
    IF g_comenzi.COUNT = 0 THEN
      DBMS_OUTPUT.PUT_LINE('[RECEPTIE] Nu exista comenzi pending.');
      RETURN;
    END IF;

    k := g_comenzi.FIRST;
    WHILE k IS NOT NULL LOOP
      -- salvam NEXT inainte de delete
      DECLARE nxt PLS_INTEGER;
      BEGIN
        nxt := g_comenzi.NEXT(k);
        p_receptioneaza_comanda_produs(k);
        k := nxt;
      END;
    END LOOP;
  END;

  PROCEDURE p_anuleaza_toate IS
  BEGIN
    g_comenzi.DELETE;
    DBMS_OUTPUT.PUT_LINE('[ANULARE] Toate comenzile pending au fost anulate.');
  END;

END pkg_gestiune_stoc;
/
SHOW ERRORS;

----------------
-- TESTE
----------------

SET SERVEROUTPUT ON;

DECLARE
  v_tip Evenimente.tip_eveniment%TYPE;

  -- Produse
  v_pA NUMBER; v_pB NUMBER; v_pC NUMBER; v_pD NUMBER; v_pE NUMBER;

  -- Evenimente
  v_e1 NUMBER; v_e2 NUMBER; v_e3 NUMBER; v_e4 NUMBER; v_e5 NUMBER; v_e6 NUMBER;
  v_tag VARCHAR2(50) := TO_CHAR(SYSTIMESTAMP,'YYYYMMDDHH24MISSFF3');

  PROCEDURE ok(p VARCHAR2) IS BEGIN DBMS_OUTPUT.PUT_LINE('  [OK] '||p); END;
  PROCEDURE fail(p VARCHAR2) IS BEGIN DBMS_OUTPUT.PUT_LINE('  [FAIL] '||p); END;

  FUNCTION stoc(p_id NUMBER) RETURN NUMBER IS v NUMBER;
  BEGIN SELECT cantitate INTO v FROM Produse WHERE id_produs = p_id; RETURN v; END;

BEGIN
  DBMS_OUTPUT.PUT_LINE('===================== TESTE =====================');
  SAVEPOINT sp_all;

  -- tip_eveniment existent
  BEGIN
    SELECT tip_eveniment INTO v_tip FROM Evenimente WHERE ROWNUM = 1;
  EXCEPTION WHEN NO_DATA_FOUND THEN
    v_tip := 'TEST';
  END;

  -- Produse de test
  INSERT INTO Produse (nume_produs, cantitate, unitate_masura, pret_unitar)
  VALUES ('T_Prod_A_'||v_tag, 100, 'buc', 5) RETURNING id_produs INTO v_pA;

  INSERT INTO Produse (nume_produs, cantitate, unitate_masura, pret_unitar)
  VALUES ('T_Prod_B_'||v_tag, 2, 'buc', 10) RETURNING id_produs INTO v_pB;

  INSERT INTO Produse (nume_produs, cantitate, unitate_masura, pret_unitar)
  VALUES ('T_Prod_C_'||v_tag, 0, 'buc', 7) RETURNING id_produs INTO v_pC;

  ok('Produse create: A='||v_pA||', B='||v_pB||', C='||v_pC);

  -------------------------------------------------------------------
  -- (1) Stoc suficient -> -20104
  -------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('--- (1) Stoc suficient => astept -20104 ---');
  INSERT INTO Evenimente (tip_eveniment, data_eveniment, numar_persoane)
  VALUES (v_tip, DATE '2032-01-10', 10) RETURNING id_eveniment INTO v_e1;

  INSERT INTO Evenimente_Produse (id_eveniment, id_produs, cantitate)
  VALUES (v_e1, v_pA, 10);

  BEGIN
    pkg_gestiune_stoc.p_genereaza_comenzi(v_e1, 0, 0);
    fail('Nu a blocat comanda desi stoc suficient.');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20104 THEN ok('Blocare corecta: '||SQLERRM);
      ELSE fail('Alta eroare: '||SQLERRM);
      END IF;
  END;

  -------------------------------------------------------------------
  -- (2) Deficit produs B -> creeaza comanda pending pentru B
  -------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('--- (2) Deficit B => creeaza comanda pending B ---');
  INSERT INTO Evenimente (tip_eveniment, data_eveniment, numar_persoane)
  VALUES (v_tip, DATE '2032-01-12', 10) RETURNING id_eveniment INTO v_e2;

  INSERT INTO Evenimente_Produse (id_eveniment, id_produs, cantitate)
  VALUES (v_e2, v_pB, 10);

  pkg_gestiune_stoc.p_genereaza_comenzi(v_e2, 0, 0);
  ok('B pending creat. Stoc B inainte='||stoc(v_pB));

  -------------------------------------------------------------------
  -- (3) Cu B pending, deficit C -> permite comanda C in paralel
  -------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('--- (3) B pending + deficit C => creeaza si C ---');
  INSERT INTO Evenimente (tip_eveniment, data_eveniment, numar_persoane)
  VALUES (v_tip, DATE '2032-01-13', 10) RETURNING id_eveniment INTO v_e3;

  INSERT INTO Evenimente_Produse (id_eveniment, id_produs, cantitate)
  VALUES (v_e3, v_pC, 5);

  pkg_gestiune_stoc.p_genereaza_comenzi(v_e3, 0, 0);
  ok('C pending creat in paralel cu B.');

  pkg_gestiune_stoc.p_raport_comenzi_curente;

  -------------------------------------------------------------------
  -- (4) daca produsul B are deja comanda, IGNORA B si creeaza comenzi pentru alte produse din eveniment.
  --     Cream produs D deficit + eveniment cu (B + D).
  -------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('--- (4) Eveniment cu (B deja pending) + D deficit => IGNORA B, creeaza D ---');
  INSERT INTO Produse (nume_produs, cantitate, unitate_masura, pret_unitar)
  VALUES ('T_Prod_D_'||v_tag, 0, 'buc', 3) RETURNING id_produs INTO v_pD;

  INSERT INTO Evenimente (tip_eveniment, data_eveniment, numar_persoane)
  VALUES (v_tip, DATE '2032-01-14', 10) RETURNING id_eveniment INTO v_e4;

  INSERT INTO Evenimente_Produse (id_eveniment, id_produs, cantitate) VALUES (v_e4, v_pB, 3);
  INSERT INTO Evenimente_Produse (id_eveniment, id_produs, cantitate) VALUES (v_e4, v_pD, 4);

  -- AICI trebuie sa NU dea eroare
  BEGIN
    pkg_gestiune_stoc.p_genereaza_comenzi(v_e4, 0, 0);
    ok('A rulat fara eroare: B ignorat, D adaugat.');
  EXCEPTION
    WHEN OTHERS THEN
      fail('Nu trebuia sa dea eroare: '||SQLERRM);
  END;

  pkg_gestiune_stoc.p_raport_comenzi_curente;

  -------------------------------------------------------------------
  -- (5) Eveniment doar cu B (B pending, deficit) => NU creeaza nimic nou
  -------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('--- (5) Eveniment doar cu B pending => nu creeaza nimic nou ---');
  INSERT INTO Evenimente (tip_eveniment, data_eveniment, numar_persoane)
  VALUES (v_tip, DATE '2032-01-15', 10) RETURNING id_eveniment INTO v_e5;

  INSERT INTO Evenimente_Produse (id_eveniment, id_produs, cantitate) VALUES (v_e5, v_pB, 4);

  BEGIN
    pkg_gestiune_stoc.p_genereaza_comenzi(v_e5, 0, 0);
    ok('A rulat: B ignorat, nicio comanda noua (corect).');
  EXCEPTION
    WHEN OTHERS THEN
      fail('Nu trebuia eroare aici: '||SQLERRM);
  END;

  -------------------------------------------------------------------
  -- (6) Receptie pe toate si verificare stocuri
  -------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('--- (6) Receptie pe toate (B, C, D) + verificare stoc ---');
  DBMS_OUTPUT.PUT_LINE('  Stoc inainte: B='||stoc(v_pB)||', C='||stoc(v_pC)||', D='||stoc(v_pD));
  pkg_gestiune_stoc.p_receptioneaza_toate;
  DBMS_OUTPUT.PUT_LINE('  Stoc dupa:    B='||stoc(v_pB)||', C='||stoc(v_pC)||', D='||stoc(v_pD));
  pkg_gestiune_stoc.p_raport_comenzi_curente;

  -------------------------------------------------------------------
  -- (7) TEST 7: 2 comenzi pe 2 produse diferite + buffering
  --     - una pe orizont+buffer
  --     - una pe eveniment: initial fara buffer, anulata, refacuta cu buffer
  --     - apoi receptie pe toate
  -------------------------------------------------------------------
  DBMS_OUTPUT.PUT_LINE('--- (7) 2 comenzi pe 2 produse diferite + buffering + receptie toate ---');

  -- curatam memoria
  pkg_gestiune_stoc.p_anuleaza_toate;

  -- Produs A2 (orizont): stoc 50, cerere orizont 100, buffer 10% => tinta 110 => deficit 60
  INSERT INTO Produse (nume_produs, cantitate, unitate_masura, pret_unitar)
  VALUES ('T7_Prod_A2_'||v_tag, 50, 'buc', 5) RETURNING id_produs INTO v_pA;

  -- Produs E (eveniment): stoc 0, necesar 10, refacut cu buffer 20% => tinta 12 => deficit 12
  INSERT INTO Produse (nume_produs, cantitate, unitate_masura, pret_unitar)
  VALUES ('T7_Prod_E_'||v_tag, 0, 'buc', 9) RETURNING id_produs INTO v_pE;

  -- Eveniment initiator orizont
  INSERT INTO Evenimente (tip_eveniment, data_eveniment, numar_persoane)
  VALUES (v_tip, DATE '2033-02-01', 10) RETURNING id_eveniment INTO v_e6;
  INSERT INTO Evenimente_Produse (id_eveniment, id_produs, cantitate) VALUES (v_e6, v_pA, 40);

  -- Eveniment suplimentar in orizont (+14 zile)
  DECLARE v_e6b NUMBER;
  BEGIN
    INSERT INTO Evenimente (tip_eveniment, data_eveniment, numar_persoane)
    VALUES (v_tip, DATE '2033-02-15', 10) RETURNING id_eveniment INTO v_e6b;
    INSERT INTO Evenimente_Produse (id_eveniment, id_produs, cantitate) VALUES (v_e6b, v_pA, 60);
  END;

  DBMS_OUTPUT.PUT_LINE('  (7.1) Generez ORIZONT+BUFFER (orizont=30, buffer=10) pentru A2');
  pkg_gestiune_stoc.p_genereaza_comenzi(v_e6, 30, 10);

  -- Eveniment pentru produs E
  DECLARE v_eE NUMBER;
  BEGIN
    INSERT INTO Evenimente (tip_eveniment, data_eveniment, numar_persoane)
    VALUES (v_tip, DATE '2033-03-01', 10) RETURNING id_eveniment INTO v_eE;
    INSERT INTO Evenimente_Produse (id_eveniment, id_produs, cantitate) VALUES (v_eE, v_pE, 10);

    DBMS_OUTPUT.PUT_LINE('  (7.2) Generez EVENIMENT (buffer=0) pentru E');
    pkg_gestiune_stoc.p_genereaza_comenzi(v_eE, 0, 0);

    DBMS_OUTPUT.PUT_LINE('  (7.3) Anulez comanda E si regenerez cu buffer=20');
    pkg_gestiune_stoc.p_anuleaza_comanda_produs(v_pE);
    pkg_gestiune_stoc.p_genereaza_comenzi(v_eE, 0, 20);
  END;

  DBMS_OUTPUT.PUT_LINE('  (7.4) Comenzi pending (ambele trebuie sa arate buffer in detalii):');
  pkg_gestiune_stoc.p_raport_comenzi_curente;

  DBMS_OUTPUT.PUT_LINE('  (7.5) Receptie pe toate separat + verificare stoc:');
  DBMS_OUTPUT.PUT_LINE('    Stoc inainte: A2='||stoc(v_pA)||', E='||stoc(v_pE));
  pkg_gestiune_stoc.p_receptioneaza_comanda_produs(v_pE);
  pkg_gestiune_stoc.p_receptioneaza_comanda_produs(v_pA);
  DBMS_OUTPUT.PUT_LINE('    Stoc dupa:    A2='||stoc(v_pA)||', E='||stoc(v_pE));
  pkg_gestiune_stoc.p_raport_comenzi_curente;

  -- curatenie
  pkg_gestiune_stoc.p_anuleaza_toate;

  ROLLBACK TO sp_all;
  DBMS_OUTPUT.PUT_LINE('===================== FINAL TESTE (rollback) =====================');

EXCEPTION
  WHEN OTHERS THEN
    fail('Eroare neasteptata in teste: '||SQLERRM);
    BEGIN pkg_gestiune_stoc.p_anuleaza_toate; EXCEPTION WHEN OTHERS THEN NULL; END;
    ROLLBACK TO sp_all;
END;
/






















































































-- DECLARE
--   v_pA NUMBER; v_pB NUMBER; v_pC NUMBER;
--   v_e1 NUMBER; v_e2 NUMBER; v_e3 NUMBER; v_e4 NUMBER; v_e5 NUMBER;

--   PROCEDURE ok(p VARCHAR2) IS BEGIN DBMS_OUTPUT.PUT_LINE('  [OK] '||p); END;
--   PROCEDURE fail(p VARCHAR2) IS BEGIN DBMS_OUTPUT.PUT_LINE('  [FAIL] '||p); END;

--   FUNCTION stoc(p_id NUMBER) RETURN NUMBER IS v NUMBER;
--   BEGIN SELECT cantitate INTO v FROM Produse WHERE id_produs = p_id; RETURN v; END;

-- BEGIN
--   DBMS_OUTPUT.PUT_LINE('===================== TESTE (comenzi multiple, 1/produs) =====================');
--   SAVEPOINT sp_all;

--   -- Produse test
--   INSERT INTO Produse (nume_produs, cantitate, unitate_masura, pret_unitar)
--   VALUES ('Prod_Multi_A', 100, 'buc', 5)
--   RETURNING id_produs INTO v_pA;

--   INSERT INTO Produse (nume_produs, cantitate, unitate_masura, pret_unitar)
--   VALUES ('Prod_Multi_B', 2, 'buc', 10)
--   RETURNING id_produs INTO v_pB;

--   INSERT INTO Produse (nume_produs, cantitate, unitate_masura, pret_unitar)
--   VALUES ('Prod_Multi_C', 0, 'buc', 7)
--   RETURNING id_produs INTO v_pC;

--   -------------------------------------------------------------------
--   -- (1) stoc suficient -> -20104
--   -------------------------------------------------------------------
--   DBMS_OUTPUT.PUT_LINE('--- (1) Stoc suficient => astept -20104 ---');

--   INSERT INTO Evenimente (tip_eveniment, data_eveniment, numar_persoane)
--   VALUES ('TEST', DATE '2032-01-10', 10)
--   RETURNING id_eveniment INTO v_e1;

--   INSERT INTO Evenimente_Produse (id_eveniment, id_produs, cantitate)
--   VALUES (v_e1, v_pA, 10); -- stoc 100, necesar 10

--   BEGIN
--     pkg_gestiune_stoc.p_genereaza_comenzi(v_e1, 0, 0);
--     fail('Nu a blocat comanda desi stoc suficient.');
--   EXCEPTION
--     WHEN OTHERS THEN
--       IF SQLCODE = -20104 THEN ok('Blocare corecta: '||SQLERRM);
--       ELSE fail('Alta eroare: '||SQLERRM);
--       END IF;
--   END;

--   -------------------------------------------------------------------
--   -- (2) comanda pentru produs B (deficit) -> trebuie sa creeze 1 comanda pending
--   -------------------------------------------------------------------
--   DBMS_OUTPUT.PUT_LINE('--- (2) Deficit produs B => creeaza comanda pending ---');

--   INSERT INTO Evenimente (tip_eveniment, data_eveniment, numar_persoane)
--   VALUES ('TEST', DATE '2032-01-12', 10)
--   RETURNING id_eveniment INTO v_e2;

--   INSERT INTO Evenimente_Produse (id_eveniment, id_produs, cantitate)
--   VALUES (v_e2, v_pB, 10); -- stoc 2, necesar 10 => deficit

--   pkg_gestiune_stoc.p_genereaza_comenzi(v_e2, 0, 0);
--   ok('Comanda B pending. Stoc B inainte='||stoc(v_pB));

--   -------------------------------------------------------------------
--   -- (3) in timp ce B e pending, generam comanda pentru produs C (alt produs) -> PERMIS
--   -------------------------------------------------------------------
--   DBMS_OUTPUT.PUT_LINE('--- (3) Comenzi simultane pe produse diferite (B + C) ---');

--   INSERT INTO Evenimente (tip_eveniment, data_eveniment, numar_persoane)
--   VALUES ('TEST', DATE '2032-01-13', 10)
--   RETURNING id_eveniment INTO v_e3;

--   INSERT INTO Evenimente_Produse (id_eveniment, id_produs, cantitate)
--   VALUES (v_e3, v_pC, 5); -- stoc 0, necesar 5 => deficit

--   pkg_gestiune_stoc.p_genereaza_comenzi(v_e3, 0, 0);
--   ok('Comanda C pending in paralel cu B (produse diferite).');

--   pkg_gestiune_stoc.p_raport_comenzi_curente;

--   -------------------------------------------------------------------
--   -- (4) incercam o a doua comanda pentru acelasi produs B -> -20107
--   -------------------------------------------------------------------
--   DBMS_OUTPUT.PUT_LINE('--- (4) A doua comanda pentru acelasi produs B => astept -20107 ---');

--   INSERT INTO Evenimente (tip_eveniment, data_eveniment, numar_persoane)
--   VALUES ('TEST', DATE '2032-01-14', 10)
--   RETURNING id_eveniment INTO v_e4;

--   INSERT INTO Evenimente_Produse (id_eveniment, id_produs, cantitate)
--   VALUES (v_e4, v_pB, 3); -- ar avea deficit, dar produsul B are deja comanda pending

--   BEGIN
--     pkg_gestiune_stoc.p_genereaza_comenzi(v_e4, 0, 0);
--     fail('A permis a doua comanda pentru produs B (ar fi trebuit -20107).');
--   EXCEPTION
--     WHEN OTHERS THEN
--       IF SQLCODE = -20107 THEN ok('Blocare corecta: '||SQLERRM);
--       ELSE fail('Alta eroare: '||SQLERRM);
--       END IF;
--   END;

--   -------------------------------------------------------------------
--   -- (5) receptie doar pentru produs B -> stoc creste; C ramane pending
--   -------------------------------------------------------------------
--   DBMS_OUTPUT.PUT_LINE('--- (5) Receptie pe produs B (C ramane pending) ---');
--   pkg_gestiune_stoc.p_receptioneaza_comanda_produs(v_pB);
--   ok('Stoc B dupa receptie='||stoc(v_pB));

--   pkg_gestiune_stoc.p_raport_comenzi_curente;

--   -- receptie din nou pe B -> -20105
--   BEGIN
--     pkg_gestiune_stoc.p_receptioneaza_comanda_produs(v_pB);
--     fail('A permis receptie fara comanda (B).');
--   EXCEPTION
--     WHEN OTHERS THEN
--       IF SQLCODE = -20105 THEN ok('Blocare corecta receptie fara comanda: '||SQLERRM);
--       ELSE fail('Alta eroare: '||SQLERRM);
--       END IF;
--   END;

--   -------------------------------------------------------------------
--   -- (6) receptie toate (ramane doar C) -> acum C se receptioneaza
--   -------------------------------------------------------------------
--   DBMS_OUTPUT.PUT_LINE('--- (6) Receptie toate (pentru comanda C) ---');
--   pkg_gestiune_stoc.p_receptioneaza_toate;
--   ok('Stoc C dupa receptie='||stoc(v_pC));

--   pkg_gestiune_stoc.p_raport_comenzi_curente;

--   -------------------------------------------------------------------
--   -- (7) test orizont pe produs A + duplicare pe produs A
--   -- stoc A=100, evt5 cere 60, alt eveniment in orizont cere 70 => cerere 130 => deficit 30
--   -------------------------------------------------------------------
--   DBMS_OUTPUT.PUT_LINE('--- (7) Orizont pe produs A + blocare duplicare produs A ---');

--   INSERT INTO Evenimente (tip_eveniment, data_eveniment, numar_persoane)
--   VALUES ('TEST', DATE '2032-02-01', 10)
--   RETURNING id_eveniment INTO v_e5;

--   INSERT INTO Evenimente_Produse (id_eveniment, id_produs, cantitate)
--   VALUES (v_e5, v_pA, 60);

--   -- alt eveniment in orizont
--   DECLARE v_e6 NUMBER;
--   BEGIN
--     INSERT INTO Evenimente (tip_eveniment, data_eveniment, numar_persoane)
--     VALUES ('TEST', DATE '2032-02-10', 10)
--     RETURNING id_eveniment INTO v_e6;

--     INSERT INTO Evenimente_Produse (id_eveniment, id_produs, cantitate)
--     VALUES (v_e6, v_pA, 70);
--   END;

--   pkg_gestiune_stoc.p_genereaza_comenzi(v_e5, 30, 0); -- ar trebui sa creeze comanda pentru A
--   ok('Comanda A pending (orizont).');

--   -- incercam sa generam inca o comanda pt produs A (orice eveniment ce include A) => -20107
--   BEGIN
--     pkg_gestiune_stoc.p_genereaza_comenzi(v_e5, 30, 0);
--     fail('A permis a doua comanda pentru produs A (ar fi trebuit -20107).');
--   EXCEPTION
--     WHEN OTHERS THEN
--       IF SQLCODE = -20107 THEN ok('Blocare corecta pe produs A: '||SQLERRM);
--       ELSE fail('Alta eroare: '||SQLERRM);
--       END IF;
--   END;

--   -- anulam comanda A
--   pkg_gestiune_stoc.p_anuleaza_comanda_produs(v_pA);
--   pkg_gestiune_stoc.p_raport_comenzi_curente;

--   -- curatam orice ramas
--   pkg_gestiune_stoc.p_anuleaza_toate;

--   ROLLBACK TO sp_all;
--   DBMS_OUTPUT.PUT_LINE('===================== FINAL TESTE (rollback) =====================');

-- END;
-- /
