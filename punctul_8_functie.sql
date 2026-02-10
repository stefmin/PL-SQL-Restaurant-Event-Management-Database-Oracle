-- ============================================================
-- PUNCTUL 8 (Proiect SGBD 2025-2026)

-- Problema (limbaj natural):
--   "Pentru un client si o zi data, determina sala in care clientul are rezervare
--    (si detalii despre rezervare). Daca nu exista rezervare -> NO_DATA_FOUND.
--    Daca exista mai multe rezervari in aceeasi zi pentru acel client -> TOO_MANY_ROWS."
--
-- Tabele folosite in comanda SQL (exact 3):
--   CLIENTI, REZERVARI, SALI
-- ============================================================

SET SERVEROUTPUT ON;

-- optional curatare
BEGIN
  EXECUTE IMMEDIATE 'DROP FUNCTION f_detalii_rezervare_client_zi';
EXCEPTION
  WHEN OTHERS THEN NULL;
END;
/
SHOW ERRORS;

CREATE OR REPLACE FUNCTION f_detalii_rezervare_client_zi(
    p_id_client IN NUMBER,
    p_data      IN DATE
) RETURN VARCHAR2
AS
    -- exceptie proprie pentru parametri invalizi
    e_param_invalizi EXCEPTION;

    v_rezultat VARCHAR2(4000);
BEGIN
    IF p_id_client IS NULL OR p_data IS NULL OR p_id_client <> TRUNC(p_id_client) THEN
        RAISE e_param_invalizi;
    END IF;

    -- O singura comanda SQL care foloseste 3 tabele: Clienti, Rezervari, Sali
    SELECT
        'Client: ' || c.nume || ' ' || c.prenume ||
        ' | Sala: '  || s.nume_sala ||
        ' | Data: '  || TO_CHAR(r.data_rezervare, 'YYYY-MM-DD') ||
        ' | Ora: '   || r.ora_rezervare ||
        ' | Persoane: ' || r.numar_persoane
    INTO v_rezultat
    FROM Clienti c
    JOIN Rezervari r ON r.id_client = c.id_client
    JOIN Sali s      ON s.id_sala   = r.id_sala
    WHERE c.id_client = p_id_client
      AND TRUNC(r.data_rezervare) = TRUNC(p_data);

    RETURN v_rezultat;

EXCEPTION
    WHEN e_param_invalizi THEN
        DBMS_OUTPUT.PUT_LINE('[PARAMETRI INVALIZI] id_client sau data nu sunt corecte.');
        RETURN 'PARAMETRI INVALIZI';

    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('[NO_DATA_FOUND] Nu exista rezervare pentru clientul ' || p_id_client ||
                             ' la data ' || TO_CHAR(p_data, 'YYYY-MM-DD') || '.');
        RETURN 'NU EXISTA REZERVARE';

    WHEN TOO_MANY_ROWS THEN
        DBMS_OUTPUT.PUT_LINE('[TOO_MANY_ROWS] Exista mai multe rezervari pentru clientul ' || p_id_client ||
                             ' la data ' || TO_CHAR(p_data, 'YYYY-MM-DD') || '.');
        DBMS_OUTPUT.PUT_LINE('Lista rezervarilor din acea zi:');

        FOR rr IN (
            SELECT r.id_rezervare,
                   TO_CHAR(r.data_rezervare, 'YYYY-MM-DD') AS data_rez,
                   r.ora_rezervare,
                   r.numar_persoane,
                   s.nume_sala
            FROM Rezervari r
            JOIN Sali s ON s.id_sala = r.id_sala
            WHERE r.id_client = p_id_client
              AND TRUNC(r.data_rezervare) = TRUNC(p_data)
            ORDER BY r.ora_rezervare, r.id_rezervare
        ) LOOP
            DBMS_OUTPUT.PUT_LINE(' - Rez#' || rr.id_rezervare ||
                                 ' | ' || rr.data_rez ||
                                 ' ' || rr.ora_rezervare ||
                                 ' | sala=' || rr.nume_sala ||
                                 ' | persoane=' || rr.numar_persoane);
        END LOOP;

        RETURN 'PREA MULTE REZERVARI';

    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('[ALTA EROARE] ' || SQLERRM);
        RETURN 'EROARE: ' || SQLERRM;
END;
/
SHOW ERRORS;

-- ============================================================
-- APELURI DE TEST
-- ============================================================
DECLARE
    v_client_id NUMBER := 1;  -- presupunere standard in setul de date 7/12 (ID-uri identity de la 1)
    v_sala_id   NUMBER := 1;
    v_data_ok   DATE   := DATE '2099-12-30';
BEGIN
    DBMS_OUTPUT.PUT_LINE('================ TEST PUNCTUL 8 ================');

    -- Folosim SAVEPOINT ca sa nu "murdarim" baza de date dupa demonstratie
    SAVEPOINT sp_test_8;

    -- 1) Caz NORMAL: exact o rezervare in acea zi
    INSERT INTO Rezervari (data_rezervare, ora_rezervare, numar_persoane, id_client, id_sala)
    VALUES (v_data_ok, '12:00', 4, v_client_id, v_sala_id);

    DBMS_OUTPUT.PUT_LINE('--- Caz normal (1 rand) ---');
    DBMS_OUTPUT.PUT_LINE(f_detalii_rezervare_client_zi(v_client_id, v_data_ok));

    -- 2) Caz NO_DATA_FOUND: zi fara rezervare
    DBMS_OUTPUT.PUT_LINE('--- Caz NO_DATA_FOUND ---');
    DBMS_OUTPUT.PUT_LINE(f_detalii_rezervare_client_zi(v_client_id, DATE '2099-12-29'));
    DBMS_OUTPUT.PUT_LINE(f_detalii_rezervare_client_zi(v_client_id, NULL));

    -- 3) Caz TOO_MANY_ROWS: introducem a doua rezervare in aceeasi zi pentru acelasi client
    INSERT INTO Rezervari (data_rezervare, ora_rezervare, numar_persoane, id_client, id_sala)
    VALUES (v_data_ok, '14:00', 2, v_client_id, v_sala_id);

    DBMS_OUTPUT.PUT_LINE('--- Caz TOO_MANY_ROWS ---');
    DBMS_OUTPUT.PUT_LINE(f_detalii_rezervare_client_zi(v_client_id, v_data_ok));

    -- 4) Caz parametri invalizi (exceptie proprie)
    DBMS_OUTPUT.PUT_LINE('--- Caz parametri invalizi ---');
    DBMS_OUTPUT.PUT_LINE(f_detalii_rezervare_client_zi(v_client_id, NULL));

    DBMS_OUTPUT.PUT_LINE('--- Caz parametri invalizi 2---');
    DBMS_OUTPUT.PUT_LINE(f_detalii_rezervare_client_zi(1.5, DATE '2099-12-29'));

    -- revenim la starea initiala
    ROLLBACK TO sp_test_8;

    DBMS_OUTPUT.PUT_LINE('================================================');
END;
/

-- SET SERVEROUTPUT ON;

DECLARE
  v_ret VARCHAR2(4000);

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

  PROCEDURE try_p8 IS
  BEGIN
    v_ret := f_detalii_rezervare_client_zi(1, DATE '2099-01-01');
    DBMS_OUTPUT.PUT_LINE('   Return: ' || v_ret);
    DBMS_OUTPUT.PUT_LINE('   -> OK (nu a aruncat exceptie ne-prinsa)');
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('   -> EROARE NEPRINSA: ' || SQLERRM);
  END;

BEGIN
  DBMS_OUTPUT.PUT_LINE('================= TEST P8: tabele goale =================');
  SAVEPOINT sp8;

  -- (A) CLIENTI gol (stergem intai Rezervari)
  DBMS_OUTPUT.PUT_LINE('--- (A) CLIENTI gol ---');
  SAVEPOINT tA;
  safe_exec('DELETE FROM Rezervari');
  safe_exec('DELETE FROM Participari_evenimente');
  safe_exec('DELETE FROM Comenzi_produse');
  safe_exec('DELETE FROM Comenzi_angajati');
  safe_exec('DELETE FROM Comenzi');
  safe_exec('DELETE FROM Clienti');
  safe_count('Clienti');
  try_p8;
  ROLLBACK TO tA;

  -- (B) REZERVARI gol
  DBMS_OUTPUT.PUT_LINE('--- (B) REZERVARI gol ---');
  SAVEPOINT tB;
  safe_exec('DELETE FROM Rezervari');
  safe_count('Rezervari');
  try_p8;
  ROLLBACK TO tB;

  -- (C) SALI gol (necesita sa golesti tabele care refera SALI)
  DBMS_OUTPUT.PUT_LINE('--- (C) SALI gol ---');
  SAVEPOINT tC;
  safe_exec('DELETE FROM Rezervari');
  safe_exec('DELETE FROM Planificari_organizatorice');
  safe_exec('DELETE FROM Sali');
  safe_count('Sali');
  try_p8;
  ROLLBACK TO tC;

  ROLLBACK TO sp8;
  DBMS_OUTPUT.PUT_LINE('===========================================================');
END;
/

ROLLBACK;
/





