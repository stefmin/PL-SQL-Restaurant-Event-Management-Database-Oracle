-- ============================================================
-- PUNCTUL 6 (Proiect SGBD 2025-2026)
-- Subprogram stocat independent care utilizeaza toate cele 3 tipuri de colectii:
--   (1) VARRAY
--   (2) NESTED TABLE
--   (3) ASSOCIATIVE ARRAY (INDEX BY)
--
-- Problema (in limbaj natural, adaptata bazei de date):
--   Pentru un eveniment dat (id_eveniment), sa se genereze un raport logistic care:
--     - afiseaza detalii despre eveniment (tip, data, numar_persoane);
--     - calculeaza capacitatea totala a salilor alocate evenimentului;
--     - listeaza produsele necesare evenimentului (cantitati) si verifica daca stocul este suficient;
--     - calculeaza costul estimat pentru produsele necesare;
--     - afiseaza alerte (ex: stoc insuficient, capacitate insuficienta, lipsa planificare).
--
-- Implementare colectii:
--   - NESTED TABLE: lista de id-uri de produse folosite la eveniment (din Evenimente_Produse)
--   - ASSOCIATIVE ARRAY: mapare id_produs -> cantitate_necesara
--   - VARRAY: lista (max 10) de mesaje de alerta
-- ============================================================

-- SET SERVEROUTPUT ON;

-- DROP TYPE t_alerte FORCE
-- DROP TYPE t_lista_produse FORCE


-- (1) VARRAY: lista fixa de alerte
CREATE OR REPLACE TYPE t_alerte IS VARRAY(10) OF VARCHAR2(200);
/
-- (2) NESTED TABLE: lista de id-uri de produse pentru eveniment
CREATE OR REPLACE TYPE t_lista_produse IS TABLE OF NUMBER;
/

CREATE OR REPLACE PROCEDURE raport_logistic_eveniment(
    p_id_eveniment IN NUMBER
) AS
    
    -- (3) ASSOCIATIVE ARRAY: mapare id_produs -> cantitate necesara
    TYPE t_necesar_map IS TABLE OF NUMBER INDEX BY PLS_INTEGER;

    v_alerte        t_alerte := t_alerte();
    v_id_produse    t_lista_produse := t_lista_produse();
    v_necesar       t_necesar_map;

    v_tip_eveniment  Evenimente.tip_eveniment%TYPE;
    v_data_eveniment Evenimente.data_eveniment%TYPE;
    v_nr_pers        Evenimente.numar_persoane%TYPE;

    v_cap_totala     NUMBER := 0;
    v_participanti   NUMBER := 0;

    v_cost_produse   NUMBER := 0;
    -- v_cost_animatori NUMBER := 0;

    PROCEDURE add_alert(p_msg IN VARCHAR2) IS
    BEGIN
        IF v_alerte.COUNT < v_alerte.LIMIT THEN
            v_alerte.EXTEND;
            v_alerte(v_alerte.COUNT) := p_msg;
        END IF;
    END;

BEGIN
    -- 1) Detalii eveniment
    BEGIN
        SELECT tip_eveniment, data_eveniment, numar_persoane
        INTO   v_tip_eveniment, v_data_eveniment, v_nr_pers
        FROM   Evenimente
        WHERE  id_eveniment = p_id_eveniment;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Nu exista eveniment cu id_eveniment = ' || p_id_eveniment);
            RETURN;
    END;

    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('RAPORT LOGISTIC - Eveniment #' || p_id_eveniment);
    DBMS_OUTPUT.PUT_LINE('Tip: ' || v_tip_eveniment || ' | Data: ' || TO_CHAR(v_data_eveniment, 'YYYY-MM-DD') ||
                         ' | Nr. persoane: ' || v_nr_pers);
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');

    -- 2) Capacitate totala a salilor alocate (distinct)
    SELECT NVL(SUM(s.capacitate), 0)
    INTO   v_cap_totala
    FROM   Sali s
    WHERE  s.id_sala IN (
        SELECT DISTINCT po.id_sala
        FROM Planificari_organizatorice po
        WHERE po.id_eveniment = p_id_eveniment
    );

    IF v_cap_totala = 0 THEN
        add_alert('Nu exista sali alocate (Planificari_organizatorice) pentru acest eveniment.');
    ELSIF v_nr_pers > v_cap_totala THEN
        add_alert('Capacitate insuficienta: ' || v_cap_totala || ' locuri pentru ' || v_nr_pers || ' persoane.');
    END IF;

    -- 3) Numar participanti inscrisi (din participari)
    SELECT COUNT(*)
    INTO   v_participanti
    FROM   Participari_evenimente
    WHERE  id_eveniment = p_id_eveniment;

    DBMS_OUTPUT.PUT_LINE('Capacitate sali (total): ' || v_cap_totala);
    DBMS_OUTPUT.PUT_LINE('Participanti inregistrati: ' || v_participanti);

    -- 5) Colectare produse necesare (NESTED TABLE) + mapare cantitati (ASSOCIATIVE)
    SELECT ep.id_produs
    BULK COLLECT INTO v_id_produse
    FROM Evenimente_Produse ep
    WHERE ep.id_eveniment = p_id_eveniment
    ORDER BY ep.id_produs;

    FOR ep IN (
        SELECT id_produs, cantitate
        FROM Evenimente_Produse
        WHERE id_eveniment = p_id_eveniment
    ) LOOP
        v_necesar(ep.id_produs) := ep.cantitate;
    END LOOP;

    IF v_id_produse.COUNT = 0 THEN
        add_alert('Nu exista produse asociate evenimentului (Evenimente_Produse).');
    END IF;

    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Produse necesare (necesar vs stoc):');

    -- Folosim NESTED TABLE in SQL: TABLE(v_id_produse)
    FOR p IN (
        SELECT p2.id_produs, p2.nume_produs, p2.cantitate AS stoc,
               p2.unitate_masura, p2.pret_unitar
        FROM Produse p2
        WHERE p2.id_produs IN (SELECT COLUMN_VALUE FROM TABLE(v_id_produse))
        ORDER BY p2.id_produs
    ) LOOP
        DECLARE
            v_req NUMBER;
        BEGIN
            v_req := NVL(v_necesar(p.id_produs), 0);
            v_cost_produse := v_cost_produse + (v_req * p.pret_unitar);

            DBMS_OUTPUT.PUT_LINE(' - #' || p.id_produs || ' ' || RPAD(p.nume_produs, 20) ||
                                 ' necesar=' || TO_CHAR(v_req) || ' ' || p.unitate_masura ||
                                 ' | stoc=' || TO_CHAR(p.stoc) || ' ' || p.unitate_masura ||
                                 ' | pret_unitar=' || TO_CHAR(p.pret_unitar));

            IF v_req > p.stoc THEN
                add_alert('Stoc insuficient pentru produsul "' || p.nume_produs || '": necesar ' || v_req ||
                          ', stoc ' || p.stoc || '.');
            END IF;
        END;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('Cost estimat produse (necesar * pret_unitar): ' || TO_CHAR(v_cost_produse, '9999990D00'));

    -- 7) Afisare alerte (VARRAY)
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
    IF v_alerte.COUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Alerte: (niciuna)');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Alerte (' || v_alerte.COUNT || '):');
        FOR i IN 1 .. v_alerte.COUNT LOOP
            DBMS_OUTPUT.PUT_LINE(' ! ' || v_alerte(i));
        END LOOP;
    END IF;

    DBMS_OUTPUT.PUT_LINE('============================================================');

END;
/

-- ============================================================
-- APEL (exemplu) 
-- ============================================================
BEGIN
    raport_logistic_eveniment(7);
END;
/


SET SERVEROUTPUT ON;

DECLARE
  v_evt_fara_tot     NUMBER;
  v_evt_cap_stoc     NUMBER;
  v_sala_mica        NUMBER;
  v_ang              NUMBER;
  v_prod             NUMBER;
  v_mail             VARCHAR2(200);
BEGIN
  DBMS_OUTPUT.PUT_LINE('================= TEST PUNCTUL 6 =================');
  SAVEPOINT sp6;

  -- Caz 1: eveniment inexistent (NO_DATA_FOUND tratat in procedura)
  DBMS_OUTPUT.PUT_LINE('--- Caz 1: eveniment inexistent ---');
  raport_logistic_eveniment(-1);
  raport_logistic_eveniment(NULL);

  -- Caz 2: eveniment existent, dar fara sali + fara produse (alerte)
  DBMS_OUTPUT.PUT_LINE('--- Caz 2: fara sali + fara produse ---');
  INSERT INTO Evenimente (tip_eveniment, data_eveniment, numar_persoane)
  VALUES ('TEST_P6_FARA', DATE '2099-01-01', 10)
  RETURNING id_eveniment INTO v_evt_fara_tot;

  raport_logistic_eveniment(v_evt_fara_tot);

  -- Caz 3: capacitate insuficienta + stoc insuficient (alerte)
  DBMS_OUTPUT.PUT_LINE('--- Caz 3: capacitate insuficienta + stoc insuficient ---');

  INSERT INTO Sali (nume_sala, capacitate)
  VALUES ('SALA_TEST_P6', 5)
  RETURNING id_sala INTO v_sala_mica;

  v_mail := 'p6_' || TO_CHAR(SYSTIMESTAMP,'YYYYMMDDHH24MISSFF3') || '@ex.com';
  INSERT INTO Angajati (nume, prenume, functie, salariu, mail)
  VALUES ('Test', 'P6', 'Chelner', 3000, v_mail)
  RETURNING id_angajat INTO v_ang;

  INSERT INTO Evenimente (tip_eveniment, data_eveniment, numar_persoane)
  VALUES ('TEST_P6_CAP_STOC', DATE '2099-01-02', 50)
  RETURNING id_eveniment INTO v_evt_cap_stoc;

  -- (daca la tine PK la planificari e (id_angajat,id_eveniment) e ok; daca e pe 3 coloane, e tot ok)
  INSERT INTO Planificari_organizatorice (id_angajat, id_eveniment, id_sala, observatii)
  VALUES (v_ang, v_evt_cap_stoc, v_sala_mica, 'test capacitate');

  INSERT INTO Produse (nume_produs, cantitate, unitate_masura, pret_unitar)
  VALUES ('PROD_TEST_P6', 1, 'buc', 10)
  RETURNING id_produs INTO v_prod;

  INSERT INTO Evenimente_Produse (id_eveniment, id_produs, cantitate)
  VALUES (v_evt_cap_stoc, v_prod, 10);

  raport_logistic_eveniment(v_evt_cap_stoc);

  ROLLBACK TO sp6;
  DBMS_OUTPUT.PUT_LINE('===================================================');
END;
/

SET SERVEROUTPUT ON;

DECLARE
  v_evt_test NUMBER;
  v_tip      Evenimente.tip_eveniment%TYPE;

  PROCEDURE safe_exec(p_sql VARCHAR2) IS
  BEGIN
    EXECUTE IMMEDIATE p_sql;
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('   [WARN] ' || p_sql || ' -> ' || SQLERRM);
  END;

  PROCEDURE safe_count(p_table VARCHAR2) IS
    v_cnt NUMBER;
  BEGIN
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || p_table INTO v_cnt;
    DBMS_OUTPUT.PUT_LINE('   COUNT(' || p_table || ') = ' || v_cnt);
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('   COUNT(' || p_table || ') = ? -> ' || SQLERRM);
  END;

  PROCEDURE try_p6(p_evt NUMBER) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE('   Apel: raport_logistic_eveniment(' || p_evt || ')');
    raport_logistic_eveniment(p_evt);
    DBMS_OUTPUT.PUT_LINE('   -> OK (nu a aruncat exceptie ne-prinsa)');
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('   -> EROARE NEPRINSA: ' || SQLERRM);
  END;

BEGIN
  DBMS_OUTPUT.PUT_LINE('================= TEST P6: tabele goale =================');
  SAVEPOINT sp6;

  -- eveniment de test (ca sa putem apela in majoritatea subtestelor)
  BEGIN
    SELECT tip_eveniment INTO v_tip FROM Evenimente WHERE ROWNUM = 1;
  EXCEPTION WHEN NO_DATA_FOUND THEN
    v_tip := 'TEST';
  END;

  INSERT INTO Evenimente (tip_eveniment, data_eveniment, numar_persoane)
  VALUES (v_tip, SYSDATE + 10, 10)
  RETURNING id_eveniment INTO v_evt_test;

  -- (A) EVENIMENTE gol
  DBMS_OUTPUT.PUT_LINE('--- (A) EVENIMENTE gol ---');
  SAVEPOINT tA;
  safe_exec('DELETE FROM Colaborari');
  safe_exec('DELETE FROM Evenimente_Produse');
  safe_exec('DELETE FROM Participari_evenimente');
  safe_exec('DELETE FROM Planificari_organizatorice');
  safe_exec('DELETE FROM Evenimente');
  safe_count('Evenimente');
  try_p6(1);
  ROLLBACK TO tA;

  -- (B) PLANIFICARI_ORGANIZATORICE gol
  DBMS_OUTPUT.PUT_LINE('--- (B) PLANIFICARI_ORGANIZATORICE gol ---');
  SAVEPOINT tB;
  safe_exec('DELETE FROM Planificari_organizatorice');
  safe_count('Planificari_organizatorice');
  try_p6(v_evt_test);
  ROLLBACK TO tB;

  -- (C) SALI gol (sterge intai dependente uzuale)
  DBMS_OUTPUT.PUT_LINE('--- (C) SALI gol ---');
  SAVEPOINT tC;
  safe_exec('DELETE FROM Planificari_organizatorice');
  safe_exec('DELETE FROM Rezervari'); -- ca sa poti goli SALI daca Rezervari refera SALI
  safe_exec('DELETE FROM Sali');
  safe_count('Sali');
  try_p6(v_evt_test);
  ROLLBACK TO tC;

  -- (D) PARTICIPARI_EVENIMENTE gol
  DBMS_OUTPUT.PUT_LINE('--- (D) PARTICIPARI_EVENIMENTE gol ---');
  SAVEPOINT tD;
  safe_exec('DELETE FROM Participari_evenimente');
  safe_count('Participari_evenimente');
  try_p6(v_evt_test);
  ROLLBACK TO tD;

  -- (E) EVENIMENTE_PRODUSE gol
  DBMS_OUTPUT.PUT_LINE('--- (E) EVENIMENTE_PRODUSE gol ---');
  SAVEPOINT tE;
  safe_exec('DELETE FROM Evenimente_Produse');
  safe_count('Evenimente_Produse');
  try_p6(v_evt_test);
  ROLLBACK TO tE;

  -- (F) PRODUSE gol (trebuie golit Evenimente_Produse intai) - daca e null
  DBMS_OUTPUT.PUT_LINE('--- (F) PRODUSE gol ---');
  SAVEPOINT tF;
  safe_exec('DELETE FROM Evenimente_Produse');
  safe_exec('DELETE FROM Liste_reduceri');
  safe_exec('DELETE FROM Comenzi_Produse');
  safe_exec('DELETE FROM Produse');
  safe_count('Produse');
  try_p6(v_evt_test);
  ROLLBACK TO tF;

  -- (G) ANGAJATI gol (trebuie golit Planificari_organizatorice intai)
  DBMS_OUTPUT.PUT_LINE('--- (G) ANGAJATI gol ---');
  SAVEPOINT tG;
  safe_exec('DELETE FROM Planificari_organizatorice');
  safe_exec('DELETE FROM Comenzi_Angajati'); -- daca exista in schema ta
  safe_exec('DELETE FROM Angajati');
  safe_count('Angajati');
  try_p6(v_evt_test);
  ROLLBACK TO tG;

  ROLLBACK TO sp6;
  DBMS_OUTPUT.PUT_LINE('===========================================================');
END;
/

