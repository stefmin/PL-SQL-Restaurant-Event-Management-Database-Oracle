-- ============================================================
-- PUNCTUL 9 (Proiect SGBD 2025-2026) - Procedura stocata independenta

-- Problema (limbaj natural):
--  "Pentru un client dat, afiseaza ultimele N evenimente la care a participat
--   (N = p_max_evenimente: 1 -> ultimul, 2 -> ultimele doua, etc.).
--   Pentru fiecare eveniment, afiseaza raportul de participare:
--   detalii eveniment, total participanti inscrisi, angajati planificati,
--   sali alocate, capacitate totala,
--   ceilalti participanti inregistrati."
-- ============================================================

SET SERVEROUTPUT ON;

BEGIN
  EXECUTE IMMEDIATE 'DROP PROCEDURE p9_raport_istoric_client';
EXCEPTION
  WHEN OTHERS THEN NULL;
END;
/
SHOW ERRORS;

CREATE OR REPLACE PROCEDURE p9_raport_istoric_client(
    p_id_client      IN NUMBER,
    p_max_evenimente IN NUMBER
)
AS
    -- Exceptii proprii (minim 2)
    e_parametri_invalizi EXCEPTION;
    e_fara_evenimente    EXCEPTION;

    v_nume_client   VARCHAR2(200);
    v_afisate       PLS_INTEGER := 0;

    -- Cursor = O singura comanda SQL care foloseste 5 tabele distincte:
    --   Clienti, Evenimente, Participari_evenimente, Planificari_organizatorice, Sali
    CURSOR c_raport(p_cid NUMBER, p_lim NUMBER) IS
      SELECT *
      FROM (
        SELECT
          e.id_eveniment,
          e.tip_eveniment,
          e.data_eveniment,
          e.numar_persoane,
          c.nume || ' ' || c.prenume AS nume_client,

          COUNT(DISTINCT pe_all.id_client) AS total_participanti_inregistrati,
          COUNT(DISTINCT po.id_angajat)    AS angajati_planificati,
          COUNT(DISTINCT po.id_sala)       AS nr_sali,

          -- capacitate totala (sum pe sali distincte) via subquery
          NVL((
              SELECT SUM(s2.capacitate)
              FROM Sali s2
              WHERE s2.id_sala IN (
                SELECT DISTINCT po2.id_sala
                FROM Planificari_organizatorice po2
                WHERE po2.id_eveniment = e.id_eveniment
              )
          ), 0) AS capacitate_totala,

          ROW_NUMBER() OVER (ORDER BY e.data_eveniment DESC, e.id_eveniment DESC) AS rn
        FROM Evenimente e
        JOIN Clienti c
          ON c.id_client = p_cid
        LEFT JOIN Participari_evenimente pe_all
          ON pe_all.id_eveniment = e.id_eveniment
        LEFT JOIN Planificari_organizatorice po
          ON po.id_eveniment = e.id_eveniment
        WHERE EXISTS (
          SELECT 1
          FROM Participari_evenimente pe
          WHERE pe.id_eveniment = e.id_eveniment
            AND pe.id_client = p_cid
        )
        GROUP BY
          e.id_eveniment, e.tip_eveniment, e.data_eveniment, e.numar_persoane,
          c.nume, c.prenume
      )
      WHERE rn <= p_lim
      ORDER BY data_eveniment DESC, id_eveniment DESC;

BEGIN
    -- 0) Validare parametri
    IF p_id_client IS NULL OR p_max_evenimente IS NULL OR p_max_evenimente < 1 OR p_id_client <> TRUNC(p_id_client) OR p_max_evenimente <> TRUNC(p_max_evenimente) THEN
      RAISE e_parametri_invalizi;
    END IF;

    -- 1) Preluam numele clientului (poate arunca NO_DATA_FOUND)
    SELECT nume || ' ' || prenume
    INTO   v_nume_client
    FROM   Clienti
    WHERE  id_client = p_id_client;

    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('ISTORIC EVENIMENTE CLIENT (P9)');
    DBMS_OUTPUT.PUT_LINE('Client #' || p_id_client || ': ' || v_nume_client);
    DBMS_OUTPUT.PUT_LINE('Ultimele N evenimente (N=' || p_max_evenimente || '), incepand cu cel mai recent.');
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');

    -- 2) Afisam raportul pentru fiecare eveniment selectat
    FOR r IN c_raport(p_id_client, p_max_evenimente) LOOP
      v_afisate := v_afisate + 1;
    
      DBMS_OUTPUT.PUT_LINE('Eveniment #' || r.id_eveniment ||
                             ' | ' || r.tip_eveniment ||
                             ' | Data: ' || TO_CHAR(r.data_eveniment, 'YYYY-MM-DD') ||
                             ' | Persoane(plan): ' || r.numar_persoane);

      DBMS_OUTPUT.PUT_LINE('  Participanti inscrisi: ' || r.total_participanti_inregistrati ||
                             ' | Angajati planificati: ' || r.angajati_planificati);

      DBMS_OUTPUT.PUT_LINE('  Sali: ' || r.nr_sali ||
                             ' | Capacitate totala: ' || r.capacitate_totala);

      -- Lista altor clienti inscrisi la eveniment (cu colectie + exceptii specifice colectiilor)
      DECLARE
        TYPE t_alti_clienti_nt IS TABLE OF VARCHAR2(200); -- NESTED TABLE (PL/SQL)
        v_alti_clienti t_alti_clienti_nt;                 -- va fi populata prin BULK COLLECT
      BEGIN
        SELECT 'Client #' || c2.id_client || ': ' || c2.nume || ' ' || c2.prenume
        BULK COLLECT INTO v_alti_clienti
        FROM   Participari_evenimente pe2
        JOIN   Clienti c2 ON c2.id_client = pe2.id_client
        WHERE  pe2.id_eveniment = r.id_eveniment
          AND  pe2.id_client <> p_id_client
        ORDER BY c2.id_client;
      
        -- Afisare: incercam sa afisam primul element; daca nu exista -> SUBSCRIPT_BEYOND_COUNT
        BEGIN
          DBMS_OUTPUT.PUT_LINE('  Alti clienti inregistrati:');
          DBMS_OUTPUT.PUT_LINE('    - ' || v_alti_clienti(1)); -- daca lista e goala -> exceptie
      
          IF v_alti_clienti.COUNT > 1 THEN
            FOR i IN 2 .. v_alti_clienti.COUNT LOOP
              DBMS_OUTPUT.PUT_LINE('    - ' || v_alti_clienti(i));
            END LOOP;
          END IF;
      
          DBMS_OUTPUT.PUT_LINE('    (Total alti clienti: ' || v_alti_clienti.COUNT || ')');
      
        EXCEPTION
          WHEN SUBSCRIPT_BEYOND_COUNT THEN
            DBMS_OUTPUT.PUT_LINE('  Alti clienti inregistrati: (niciunul) -> clientul este singurul inregistrat.');
      
          WHEN COLLECTION_IS_NULL THEN
            DBMS_OUTPUT.PUT_LINE('  [EROARE COLECTIE] Colectia este NULL (COLLECTION_IS_NULL).');
      
          WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('  [EROARE COLECTIE] ' || SQLERRM);
        END;
      END;
      
      DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');

    END LOOP;

    -- 3) Daca nu exista evenimente pentru client
    IF v_afisate = 0 THEN
      RAISE e_fara_evenimente;
    END IF;

    DBMS_OUTPUT.PUT_LINE('Total evenimente afisate: ' || v_afisate);
    DBMS_OUTPUT.PUT_LINE('============================================================');

EXCEPTION
    WHEN e_parametri_invalizi THEN
      DBMS_OUTPUT.PUT_LINE('[P9] PARAMETRI INVALIDI: p_id_client si p_max_evenimente trebuie sa fie nenule, iar p_max_evenimente >=1 si ambele sunt numere intregi.');

    WHEN e_fara_evenimente THEN
      DBMS_OUTPUT.PUT_LINE('[P9] NU EXISTA EVENIMENTE: clientul #' || p_id_client ||
                           ' nu are participari inregistrate.');

    WHEN NO_DATA_FOUND THEN
      DBMS_OUTPUT.PUT_LINE('[P9] NO_DATA_FOUND: nu exista client cu id_client=' || p_id_client);

    WHEN TOO_MANY_ROWS THEN
      DBMS_OUTPUT.PUT_LINE('[P9] TOO_MANY_ROWS: o interogare SELECT INTO a returnat mai multe randuri.');

    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('[P9] ALTA EROARE: ' || SQLERRM);
END;
/
SHOW ERRORS;

-- ============================================================
-- TESTARE
-- ============================================================
DECLARE
  v_client_ok     NUMBER;
  v_client_fara   NUMBER;

  v_tip_existent Evenimente.tip_eveniment%TYPE;

  v_evt_singur  NUMBER;  -- id_eveniment pentru cazul clientul e singurul
  v_evt_multi   NUMBER;  -- id_eveniment pentru cazul mai multi alti clienti
  v_c2          NUMBER;  -- id_client pentru primul client extra
  v_c3          NUMBER;  -- id_client pentru al doilea client extra


BEGIN
  DBMS_OUTPUT.PUT_LINE('================= TEST PUNCTUL 9 =================');
  SAVEPOINT sp9;

  -- A) Alegem un client existent (sau cream unul daca tabela e goala)
  BEGIN
    SELECT MIN(id_client) INTO v_client_ok FROM Clienti;
    IF v_client_ok IS NULL THEN
      INSERT INTO Clienti (nume, prenume, nr_tel, mail)
      VALUES ('Client', 'Default', '0712345678',
              'p9_' || TO_CHAR(SYSTIMESTAMP,'YYYYMMDDHH24MISSFF3') || '@ex.com')
      RETURNING id_client INTO v_client_ok;
    END IF;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      INSERT INTO Clienti (nume, prenume, nr_tel, mail)
      VALUES ('Client', 'Default', '0712345678',
              'p9_' || TO_CHAR(SYSTIMESTAMP,'YYYYMMDDHH24MISSFF3') || '@ex.com')
      RETURNING id_client INTO v_client_ok;
  END;

  -- Tip eveniment existent (ca sa treaca orice CHECK posibil)
  BEGIN
    SELECT tip_eveniment INTO v_tip_existent FROM Evenimente WHERE ROWNUM = 1;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      v_tip_existent := 'TEST';
  END;

  -- 1) Parametri invalizi (exceptie proprie)
  DBMS_OUTPUT.PUT_LINE('--- Caz 1: parametri invalizi ---');
  p9_raport_istoric_client(v_client_ok, 0);

  DBMS_OUTPUT.PUT_LINE('--- Caz 1: parametri invalizi 2---');
  p9_raport_istoric_client(v_client_ok, 1.5);

  -- 2) Client inexistent (NO_DATA_FOUND)
  DBMS_OUTPUT.PUT_LINE('--- Caz 2: client inexistent ---');
  p9_raport_istoric_client(-999999, 1);

  -- 3) Client fara participari (exceptie proprie)
  DBMS_OUTPUT.PUT_LINE('--- Caz 3: client fara participari ---');
  INSERT INTO Clienti (nume, prenume, nr_tel, mail)
  VALUES ('Client', 'FaraParticipari', '0799999999',
          'p9_nop_' || TO_CHAR(SYSTIMESTAMP,'YYYYMMDDHH24MISSFF3') || '@ex.com')
  RETURNING id_client INTO v_client_fara;

  p9_raport_istoric_client(v_client_fara, 2);

  -- 4) Eveniment unde clientul e singurul inregistrat (SUBSCRIPT_BEYOND_COUNT pe colectie)
  DBMS_OUTPUT.PUT_LINE('--- Caz 4: singurul client (lista alti clienti vida -> SUBSCRIPT_BEYOND_COUNT) ---');
  INSERT INTO Evenimente (tip_eveniment, data_eveniment, numar_persoane)
  VALUES (v_tip_existent, DATE '2099-12-30', 10)
  RETURNING id_eveniment INTO v_evt_singur;
  
  INSERT INTO Participari_evenimente (id_eveniment, id_client)
  VALUES (v_evt_singur, v_client_ok);
  
  p9_raport_istoric_client(v_client_ok, 1);
  
  -- 5) Eveniment cu mai multi alti clienti (colectia are elemente -> listare)
  DBMS_OUTPUT.PUT_LINE('--- Caz 5: mai multi clienti (colectia are elemente -> listare completa) ---');
  
  INSERT INTO Clienti (nume, prenume, nr_tel, mail)
  VALUES ('Client', 'Extra1', '0711111111',
          'p9_c2_' || TO_CHAR(SYSTIMESTAMP,'YYYYMMDDHH24MISSFF3') || '@ex.com')
  RETURNING id_client INTO v_c2;
  
  INSERT INTO Clienti (nume, prenume, nr_tel, mail)
  VALUES ('Client', 'Extra2', '0722222222',
          'p9_c3_' || TO_CHAR(SYSTIMESTAMP,'YYYYMMDDHH24MISSFF3') || '@ex.com')
  RETURNING id_client INTO v_c3;
  
  INSERT INTO Evenimente (tip_eveniment, data_eveniment, numar_persoane)
  VALUES (v_tip_existent, DATE '2100-01-01', 20)
  RETURNING id_eveniment INTO v_evt_multi;
  
  INSERT INTO Participari_evenimente (id_eveniment, id_client)
  VALUES (v_evt_multi, v_client_ok);
  
  INSERT INTO Participari_evenimente (id_eveniment, id_client)
  VALUES (v_evt_multi, v_c2);
  
  INSERT INTO Participari_evenimente (id_eveniment, id_client)
  VALUES (v_evt_multi, v_c3);
  
  p9_raport_istoric_client(v_client_ok, 1);
  
  ROLLBACK TO sp9;
  DBMS_OUTPUT.PUT_LINE('===================================================');
END;
/

-- SET SERVEROUTPUT ON;

DECLARE
  PROCEDURE safe_exec(p_sql VARCHAR2) IS
  BEGIN
    EXECUTE IMMEDIATE p_sql;
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('   [WARN] ' || p_sql || ' -> ' || SQLERRM);
  END;

  PROCEDURE safe_count(p_table VARCHAR2) IS
    v_cnt NUMBER;
  BEGIN
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || p_table INTO v_cnt;
    DBMS_OUTPUT.PUT_LINE('   COUNT(' || p_table || ') = ' || v_cnt);
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('   COUNT(' || p_table || ') = ? -> ' || SQLERRM);
  END;

  PROCEDURE try_p9 IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE('   Apel: p9_raport_istoric_client(1, 2)');
    p9_raport_istoric_client(1, 2);
    DBMS_OUTPUT.PUT_LINE('   -> OK (nu a aruncat exceptie ne-prinsa)');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('   -> EROARE NEPRINSA: ' || SQLERRM);
  END;

BEGIN
  DBMS_OUTPUT.PUT_LINE('================= TEST P9: tabele goale =================');
  SAVEPOINT sp9;

  -- (A) CLIENTI gol (stergem dependente uzuale)
  DBMS_OUTPUT.PUT_LINE('--- (A) CLIENTI gol ---');
  SAVEPOINT tA;
  safe_exec('DELETE FROM Rezervari');
  safe_exec('DELETE FROM Participari_evenimente');
  safe_exec('DELETE FROM Comenzi_produse');
  safe_exec('DELETE FROM Comenzi_angajati');
  safe_exec('DELETE FROM Comenzi');
  safe_exec('DELETE FROM Clienti');
  safe_count('Clienti');
  try_p9;
  ROLLBACK TO tA;

  -- (B) EVENIMENTE gol
  DBMS_OUTPUT.PUT_LINE('--- (B) EVENIMENTE gol ---');
  SAVEPOINT tB;
  safe_exec('DELETE FROM Participari_evenimente');
  safe_exec('DELETE FROM Planificari_organizatorice');
  safe_exec('DELETE FROM Colaborari');
  safe_exec('DELETE FROM Evenimente_produse');
  safe_exec('DELETE FROM Evenimente');
  safe_count('Evenimente');
  try_p9;
  ROLLBACK TO tB;

  -- (C) PARTICIPARI_EVENIMENTE gol
  DBMS_OUTPUT.PUT_LINE('--- (C) PARTICIPARI_EVENIMENTE gol ---');
  SAVEPOINT tC;
  safe_exec('DELETE FROM Participari_evenimente');
  safe_count('Participari_evenimente');
  try_p9;
  ROLLBACK TO tC;

  -- (D) PLANIFICARI_ORGANIZATORICE gol
  DBMS_OUTPUT.PUT_LINE('--- (D) PLANIFICARI_ORGANIZATORICE gol ---');
  SAVEPOINT tD;
  safe_exec('DELETE FROM Planificari_organizatorice');
  safe_count('Planificari_organizatorice');
  try_p9;
  ROLLBACK TO tD;

  -- (E) SALI gol (necesita sa golesti tabele care refera SALI)
  DBMS_OUTPUT.PUT_LINE('--- (E) SALI gol ---');
  SAVEPOINT tE;
  safe_exec('DELETE FROM Rezervari');
  safe_exec('DELETE FROM Planificari_organizatorice');
  safe_exec('DELETE FROM Sali');
  safe_count('Sali');
  try_p9;
  ROLLBACK TO tE;

  ROLLBACK TO sp9;
  DBMS_OUTPUT.PUT_LINE('===========================================================');
END;
/

ROLLBACK;
/
