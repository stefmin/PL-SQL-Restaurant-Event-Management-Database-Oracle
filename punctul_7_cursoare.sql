-- ============================================================
-- CERINTA 7 (Proiect SGBD 2025-2026)
-- Problema (limbaj natural):
--   Pentru o perioada data, afisam lista evenimentelor si, pentru fiecare eveniment,
--   salile alocate si numarul de angajati planificati in fiecare sala.
--   Se folosesc 2 tipuri de cursoare:
--     (1) cursor explicit cu OPEN/FETCH/CLOSE (pentru evenimente)
--     (2) cursor parametrizat, dependent de primul (pentru salile evenimentului),
--         parcurs cu cursor FOR loop.
-- ============================================================

SET SERVEROUTPUT ON;

CREATE OR REPLACE PROCEDURE raport_evenimente_sali(
    p_data_min IN DATE,
    p_data_max IN DATE
) AS
    -- Cursor 1: explicit (OPEN/FETCH/CLOSE)
    CURSOR c_evenimente IS
        SELECT id_eveniment, tip_eveniment, data_eveniment, numar_persoane
        FROM   Evenimente
        WHERE  data_eveniment BETWEEN p_data_min AND p_data_max
        ORDER  BY data_eveniment, id_eveniment;

    v_evt c_evenimente%ROWTYPE;
    v_gasit BOOLEAN := FALSE;

    -- Cursor 2: parametrizat (dependent de cursorul 1)
    CURSOR c_sali(p_id_eveniment NUMBER) IS
        SELECT s.id_sala,
               s.nume_sala,
               s.capacitate,
               COUNT(DISTINCT po.id_angajat) AS nr_angajati
        FROM   Planificari_organizatorice po
        JOIN Sali s ON s.id_sala = po.id_sala
        WHERE  po.id_eveniment = p_id_eveniment
        GROUP  BY s.id_sala, s.nume_sala, s.capacitate
        ORDER  BY s.nume_sala;

    v_participanti NUMBER;
    v_cap_total    NUMBER;
    v_are_sali     BOOLEAN;
BEGIN
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('RAPORT EVENIMENTE -> SALI + ANGAJATI');
    DBMS_OUTPUT.PUT_LINE('Perioada: ' || TO_CHAR(p_data_min,'YYYY-MM-DD') || ' .. ' || TO_CHAR(p_data_max,'YYYY-MM-DD'));
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');

    OPEN c_evenimente;
    LOOP
        FETCH c_evenimente INTO v_evt;
        EXIT WHEN c_evenimente%NOTFOUND;

        v_gasit := TRUE;

        -- participanti inscrisi (0 daca nu exista)
        SELECT COUNT(*)
        INTO   v_participanti
        FROM   Participari_evenimente
        WHERE  id_eveniment = v_evt.id_eveniment;

        DBMS_OUTPUT.PUT_LINE('Eveniment #' || v_evt.id_eveniment ||
                             ' | ' || v_evt.tip_eveniment ||
                             ' | ' || TO_CHAR(v_evt.data_eveniment,'YYYY-MM-DD') ||
                             ' | persoane=' || v_evt.numar_persoane ||
                             ' | participanti=' || v_participanti);

        DBMS_OUTPUT.PUT_LINE('  Sali alocate:');

        v_cap_total := 0;
        v_are_sali  := FALSE;

        -- Cursor parametrizat dependent de evenimentul curent
        FOR r IN c_sali(v_evt.id_eveniment) LOOP
            v_are_sali  := TRUE;
            v_cap_total := v_cap_total + r.capacitate;

            DBMS_OUTPUT.PUT_LINE('   - ' || RPAD(r.nume_sala, 18) ||
                                 ' (cap=' || r.capacitate || ')' ||
                                 ' | angajati_planificati=' || r.nr_angajati);
        END LOOP;

        IF NOT v_are_sali THEN
            DBMS_OUTPUT.PUT_LINE('   (nu exista sali planificate pentru acest eveniment)');
        ELSE
            DBMS_OUTPUT.PUT_LINE('  Capacitate totala sali: ' || v_cap_total);

            IF v_evt.numar_persoane > v_cap_total THEN
                DBMS_OUTPUT.PUT_LINE('  ATENTIE: capacitate insuficienta pentru numarul de persoane!');
            END IF;
        END IF;

        DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
    END LOOP;
    CLOSE c_evenimente;

    IF NOT v_gasit THEN
        DBMS_OUTPUT.PUT_LINE('Nu exista evenimente in perioada selectata.');
    END IF;

    DBMS_OUTPUT.PUT_LINE('============================================================');
END;
/
SHOW ERRORS;

-- ============================================================
-- APEL (exemplu)
-- ============================================================
BEGIN
    raport_evenimente_sali(DATE '1900-01-01', DATE '2999-12-31');
END;
/


INSERT INTO Planificari_organizatorice (id_angajat, id_eveniment, id_sala, observatii) VALUES (5, 1, 2, 'servire sala mare');
INSERT INTO Planificari_organizatorice (id_angajat, id_eveniment, id_sala, observatii) VALUES (4, 1, 2, 'servire sala mare');
COMMIT;

-- DELETE FROM PLANIFICARI_ORGANIZATORICE po
-- WHERE po.ID_EVENIMENT = 1 AND (po.ID_ANGAJAT = 5 OR po.ID_ANGAJAT = 4);

SET SERVEROUTPUT ON;

DECLARE
  v_evt   NUMBER;
  v_sala  NUMBER;
  v_ang   NUMBER;
  v_mail  VARCHAR2(200);
BEGIN
  DBMS_OUTPUT.PUT_LINE('================= TEST PUNCTUL 7 =================');
  SAVEPOINT sp7;

  -- Caz 1: perioada fara evenimente (mesajul "Nu exista evenimente...")
  DBMS_OUTPUT.PUT_LINE('--- Caz 1: perioada fara evenimente ---');
  raport_evenimente_sali(DATE '1800-01-01', DATE '1800-12-31');
  raport_evenimente_sali(NULL, NULL);

  -- Caz 2: perioada cu evenimente (datele existente)
  DBMS_OUTPUT.PUT_LINE('--- Caz 2: perioada cu evenimente ---');
  raport_evenimente_sali(DATE '1900-01-01', DATE '2999-12-31');

  -- Caz 3: avertizare "capacitate insuficienta"
  DBMS_OUTPUT.PUT_LINE('--- Caz 3: capacitate insuficienta (eveniment de test) ---');

  INSERT INTO Sali (nume_sala, capacitate)
  VALUES ('SALA_TEST_P7', 5)
  RETURNING id_sala INTO v_sala;

  v_mail := 'p7_' || TO_CHAR(SYSTIMESTAMP,'YYYYMMDDHH24MISSFF3') || '@ex.com';
  INSERT INTO Angajati (nume, prenume, functie, salariu, mail)
  VALUES ('Test', 'P7', 'Chelner', 3000, v_mail)
  RETURNING id_angajat INTO v_ang;

  INSERT INTO Evenimente (tip_eveniment, data_eveniment, numar_persoane)
  VALUES ('TEST_P7', DATE '2099-02-01', 50)
  RETURNING id_eveniment INTO v_evt;

  INSERT INTO Planificari_organizatorice (id_angajat, id_eveniment, id_sala, observatii)
  VALUES (v_ang, v_evt, v_sala, 'test capacitate');

  raport_evenimente_sali(DATE '2099-02-01', DATE '2099-02-01');

  ROLLBACK TO sp7;
  DBMS_OUTPUT.PUT_LINE('===================================================');
END;
/


SET SERVEROUTPUT ON;

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

  PROCEDURE try_p7 IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE('   Apel: raport_evenimente_sali(1900-01-01, 2999-12-31)');
    raport_evenimente_sali(DATE '1900-01-01', DATE '2999-12-31');
    DBMS_OUTPUT.PUT_LINE('   -> OK (nu a aruncat exceptie ne-prinsa)');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('   -> EROARE NEPRINSA: ' || SQLERRM);
  END;

BEGIN
  DBMS_OUTPUT.PUT_LINE('================= TEST P7: tabele goale =================');
  SAVEPOINT sp7;

  -- (A) EVENIMENTE gol (stergem dependente uzuale)
  DBMS_OUTPUT.PUT_LINE('--- (A) EVENIMENTE gol ---');
  SAVEPOINT tA;
  safe_exec('DELETE FROM Participari_evenimente');
  safe_exec('DELETE FROM Planificari_organizatorice');
  safe_exec('DELETE FROM Colaborari');
  safe_exec('DELETE FROM Evenimente_produse');
  safe_exec('DELETE FROM Evenimente');
  safe_count('Evenimente');
  try_p7;
  ROLLBACK TO tA;

  -- (B) PARTICIPARI_EVENIMENTE gol
  DBMS_OUTPUT.PUT_LINE('--- (B) PARTICIPARI_EVENIMENTE gol ---');
  SAVEPOINT tB;
  safe_exec('DELETE FROM Participari_evenimente');
  safe_count('Participari_evenimente');
  try_p7;
  ROLLBACK TO tB;

  -- (C) PLANIFICARI_ORGANIZATORICE gol
  DBMS_OUTPUT.PUT_LINE('--- (C) PLANIFICARI_ORGANIZATORICE gol ---');
  SAVEPOINT tC;
  safe_exec('DELETE FROM Planificari_organizatorice');
  safe_count('Planificari_organizatorice');
  try_p7;
  ROLLBACK TO tC;

  -- (D) SALI gol (necesita sa golesti tabele care refera SALI)
  DBMS_OUTPUT.PUT_LINE('--- (D) SALI gol ---');
  SAVEPOINT tD;
  safe_exec('DELETE FROM Planificari_organizatorice');
  safe_exec('DELETE FROM Rezervari'); -- daca Rezervari refera SALI
  safe_exec('DELETE FROM Sali');
  safe_count('Sali');
  try_p7;
  ROLLBACK TO tD;

  ROLLBACK TO sp7;
  DBMS_OUTPUT.PUT_LINE('===========================================================');
END;
/
