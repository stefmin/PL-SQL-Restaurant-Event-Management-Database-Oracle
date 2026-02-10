-- ============================================================
-- Triggere pentru cerintele 10, 11, 12
--
-- 10) Trigger LMD la nivel de comanda (statement-level)
--     Valideaza programarile din PLANIFICARI_ORGANIZATORICE.
--
-- 11) Trigger LMD la nivel de linie (row-level)
--     Blocheaza rezervarile intr-o sala in care exista eveniment in aceeasi zi.
--
-- 12) Exemplu Trigger LDD (DDL)
--     Audit pentru CREATE/ALTER/DROP la nivel de schema.
-- ============================================================

-- ============================================================
-- 10) TRIGGER LMD - nivel de comanda (STATEMENT-LEVEL)
-- ============================================================
-- Idee business:
  -- - Dupa orice INSERT/UPDATE in PLANIFICARI_ORGANIZATORICE, se verifica:
  --     (1) Nu exista sala cu 2 evenimente diferite in aceeasi zi.
  --     (2) Nu exista sala in care, in aceeasi zi, exista si eveniment si rezervare.
  -- - Daca apare conflict, se respinge comanda si se afiseaza un mesaj util.
  -- - Daca, pentru data conflictului, nu mai exista nicio sala libera (toate sunt ocupate
  --   prin evenimente sau rezervari), mesajul cere mutarea datei evenimentului.

-- INSERT INTO Evenimente (tip_eveniment, data_eveniment, numar_persoane) VALUES ('botez', DATE '2026-02-14', 150);
-- COMMIT;
-- INSERT INTO Planificari_organizatorice (id_angajat, id_eveniment, id_sala, observatii) VALUES (2, 1, 1, 'servire sala mare');
-- COMMIT;



-- 10.)

BEGIN
  EXECUTE IMMEDIATE 'DROP TRIGGER trg_po_conflicte_stmt';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
CREATE OR REPLACE TRIGGER trg_po_conflicte_stmt
AFTER INSERT OR UPDATE ON Planificari_organizatorice
DECLARE
  v_sala NUMBER;
  v_data DATE;
BEGIN
  -- 1) Conflict: aceeasi sala + aceeasi zi -> 2+ evenimente diferite
  BEGIN
    SELECT x.id_sala, x.d
    INTO   v_sala, v_data
    FROM (
      SELECT po.id_sala AS id_sala,
             TRUNC(e.data_eveniment) AS d
      FROM   Planificari_organizatorice po
      JOIN   Evenimente e ON e.id_eveniment = po.id_eveniment
      GROUP  BY po.id_sala, TRUNC(e.data_eveniment)
      HAVING COUNT(DISTINCT po.id_eveniment) > 1
    ) x
    WHERE ROWNUM = 1;

    RAISE_APPLICATION_ERROR(
      -20010,
      'Planificare respinsa: sala ' || v_sala ||
      ' este alocata la mai multe evenimente in data ' || TO_CHAR(v_data,'YYYY-MM-DD') ||
      '. Alege alta sala sau muta data.'
    );
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      NULL;
  END;

  -- 2) Conflict: exista rezervari in aceeasi sala + aceeasi zi cu un eveniment planificat
  BEGIN
    SELECT x.id_sala, x.d
    INTO   v_sala, v_data
    FROM (
      SELECT DISTINCT po.id_sala AS id_sala,
             TRUNC(e.data_eveniment) AS d
      FROM   Planificari_organizatorice po
      JOIN   Evenimente e ON e.id_eveniment = po.id_eveniment
      WHERE  EXISTS (
        SELECT 1
        FROM   Rezervari r
        WHERE  r.id_sala = po.id_sala
          AND  TRUNC(r.data_rezervare) = TRUNC(e.data_eveniment)
      )
    ) x
    WHERE ROWNUM = 1;

    RAISE_APPLICATION_ERROR(
      -20011,
      'Planificare respinsa: exista rezervari in sala ' || v_sala ||
      ' la data ' || TO_CHAR(v_data,'YYYY-MM-DD') ||
      '. Reprogrameaza rezervarile sau muta data evenimentului.'
    );
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      NULL;
  END;

END;
/




-- ============================================================
-- 11) TRIGGER LMD - nivel de linie (ROW-LEVEL)
-- ============================================================
-- Idee business:
--   - Pentru fiecare rezervare inserata/modificata, se verifica daca in sala aleasa
--     exista un eveniment programat in aceeasi zi.
--   - Daca exista, se respinge rezervarea.

BEGIN
  EXECUTE IMMEDIATE 'DROP TRIGGER trg_rezervari_capacitate';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE OR REPLACE TRIGGER trg_rezervari_capacitate
BEFORE INSERT OR UPDATE ON Rezervari
FOR EACH ROW
DECLARE
  v_dummy NUMBER;
BEGIN
  --  Sala exista?
  BEGIN
    SELECT 1 INTO v_dummy
    FROM Sali
    WHERE id_sala = :NEW.id_sala;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20020, 'Sala inexistentă (id_sala='||:NEW.id_sala||').');
  END;

  -- Exista eveniment in aceeasi sala + aceeasi zi?
  BEGIN
    SELECT 1 INTO v_dummy
    FROM dual
    WHERE EXISTS (
      SELECT 1
      FROM Planificari_organizatorice po
      JOIN Evenimente e
        ON e.id_eveniment = po.id_eveniment
      WHERE po.id_sala = :NEW.id_sala
        AND TRUNC(e.data_eveniment) = TRUNC(:NEW.data_rezervare)
    );

    -- daca EXISTS a gasit ceva => respingem
    RAISE_APPLICATION_ERROR(
      -20021,
      'Rezervare respinsa: exista eveniment in sala '||:NEW.id_sala||
      ' la data '||TO_CHAR(:NEW.data_rezervare,'YYYY-MM-DD')||'.'
    );
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      NULL; -- nu exista eveniment
  END;

END;
/


-- ============================================================
-- 12) EXEMPLU TRIGGER LDD - audit la nivel de schema + blocare pe entitati
-- ============================================================


-- ALTER TRIGGER trg_audit_ddl DISABLE;
-- DROP TABLE audit_ddl;
-- DROP TABLE guard_ldd;

CREATE TABLE audit_ddl (
  id           NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  event_time   TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  db_user      VARCHAR2(30),
  os_user      VARCHAR2(128),
  host         VARCHAR2(128),
  ip_address   VARCHAR2(64),
  ddl_event    VARCHAR2(30),
  object_type  VARCHAR2(30),
  object_name  VARCHAR2(128)
);

CREATE TABLE guard_ldd (
  obj_type       VARCHAR2(30)  NOT NULL,
  obj_name       VARCHAR2(128) NOT NULL,

  active         CHAR(1) DEFAULT 'Y' NOT NULL CHECK (active IN ('Y','N')),

  block_drop     CHAR(1) DEFAULT 'N' NOT NULL CHECK (block_drop IN ('Y','N')),
  block_truncate CHAR(1) DEFAULT 'N' NOT NULL CHECK (block_truncate IN ('Y','N')),
  block_alter    CHAR(1) DEFAULT 'N' NOT NULL CHECK (block_alter IN ('Y','N')),

  reason         VARCHAR2(4000),

  CONSTRAINT pk_guard_ldd PRIMARY KEY (obj_type, obj_name),

  -- majuscule by default pt comparatii
  CONSTRAINT ck_guard_upper CHECK (obj_type = UPPER(obj_type) AND obj_name = UPPER(obj_name)),

  -- interzise tabelele folosite de trigger in lista de guard
  CONSTRAINT ck_guard_no_infra CHECK (obj_name NOT IN ('AUDIT_DDL','AUDIT_LDD','GUARD_LDD','GUARD_DDL'))
);

CREATE OR REPLACE TRIGGER trg_audit_ddl
BEFORE DDL ON SCHEMA
DECLARE
  PRAGMA AUTONOMOUS_TRANSACTION;

  v_event    VARCHAR2(30)  := ORA_SYSEVENT;
  v_type     VARCHAR2(30)  := ORA_DICT_OBJ_TYPE;
  v_name     VARCHAR2(128) := ORA_DICT_OBJ_NAME;

  v_bd CHAR(1);
  v_bt CHAR(1);
  v_ba CHAR(1);
BEGIN
  -- 1) AUDIT (nu vrem ca auditarea sa blocheze DDL-ul daca apar probleme)
  BEGIN
    INSERT INTO audit_ddl (db_user, os_user, host, ip_address, ddl_event, object_type, object_name)
    VALUES (
      SYS_CONTEXT('USERENV','SESSION_USER'),
      SYS_CONTEXT('USERENV','OS_USER'),
      SYS_CONTEXT('USERENV','HOST'),
      SYS_CONTEXT('USERENV','IP_ADDRESS'),
      v_event,
      v_type,
      v_name
    );
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      -- nu blocam DDL din cauza auditului
      NULL;
  END;

  -- 2) GUARD: nu protejam infrastructura (si nici nu vrem sa consultam guard pe ea)
  IF UPPER(v_name) IN ('AUDIT_DDL','AUDIT_LDD','GUARD_LDD','GUARD_DDL') THEN
    RETURN;
  END IF;

  -- 3) Citim regulile de guard (daca exista)
  BEGIN
    SELECT block_drop, block_truncate, block_alter
    INTO   v_bd,       v_bt,          v_ba
    FROM guard_ldd
    WHERE active   = 'Y'
      AND obj_type = UPPER(v_type)
      AND obj_name = UPPER(v_name);
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN; -- nu e protejat
    WHEN OTHERS THEN
      RETURN; -- daca guard-ul are probleme, nu blocam DDL
  END;

  -- 4) Aplicam blocarea doar pe evenimentul cerut
  IF v_event = 'DROP' AND v_bd = 'Y' THEN
    RAISE_APPLICATION_ERROR(-20050, 'DDL blocat de GUARD_LDD: DROP pe '||v_type||' '||v_name);
  ELSIF v_event = 'TRUNCATE' AND v_bt = 'Y' THEN
    RAISE_APPLICATION_ERROR(-20051, 'DDL blocat de GUARD_LDD: TRUNCATE pe '||v_type||' '||v_name);
  ELSIF v_event = 'ALTER' AND v_ba = 'Y' THEN
    RAISE_APPLICATION_ERROR(-20052, 'DDL blocat de GUARD_LDD: ALTER pe '||v_type||' '||v_name);
  END IF;

END;
/

-- ------------------------------------------------------------
-- Demonstratii
-- ------------------------------------------------------------

-- 10.)

SET SERVEROUTPUT ON;

DECLARE
  v_sala   NUMBER;
  v_ang    NUMBER;
  v_cli    NUMBER;

  v_evt_A  NUMBER; -- pentru conflict cu rezervari
  v_evt_B1 NUMBER; -- conflict eveniment-eveniment
  v_evt_B2 NUMBER;

  PROCEDURE ok(p_msg VARCHAR2) IS BEGIN DBMS_OUTPUT.PUT_LINE('  [OK] '||p_msg); END;
  PROCEDURE fail(p_msg VARCHAR2) IS BEGIN DBMS_OUTPUT.PUT_LINE('  [FAIL] '||p_msg); END;

BEGIN
  DBMS_OUTPUT.PUT_LINE('================= TEST TRIGGER 10 =================');
  SAVEPOINT sp10;

  -- setup minim
  INSERT INTO Sali (nume_sala, capacitate)
  VALUES ('Sala_T10', 20)
  RETURNING id_sala INTO v_sala;

  INSERT INTO Angajati (nume, prenume, functie, salariu, mail)
  VALUES ('Test', 'Ang_T10', 'Chelner', 3000, 't10_ang_'||TO_CHAR(SYSTIMESTAMP,'YYYYMMDDHH24MISSFF3')||'@ex.com')
  RETURNING id_angajat INTO v_ang;

  INSERT INTO Clienti (nume, prenume, nr_tel, mail)
  VALUES ('Test', 'Client_T10', '0700000000', 't10_c_'||TO_CHAR(SYSTIMESTAMP,'YYYYMMDDHH24MISSFF3')||'@ex.com')
  RETURNING id_client INTO v_cli;

  -- (1) conflict planificare vs rezervari (astept ORA-20011)
  DBMS_OUTPUT.PUT_LINE('--- (1) Conflict cu REZERVARI (astept ORA-20011) ---');

  INSERT INTO Evenimente (tip_eveniment, data_eveniment, numar_persoane)
  VALUES ('TEST', DATE '2026-02-10', 5)
  RETURNING id_eveniment INTO v_evt_A;

  INSERT INTO Rezervari (data_rezervare, ora_rezervare, numar_persoane, id_client, id_sala)
  VALUES (DATE '2026-02-10', '18:00', 2, v_cli, v_sala);

  BEGIN
    INSERT INTO Planificari_organizatorice (id_eveniment, id_sala, id_angajat, observatii)
    VALUES (v_evt_A, v_sala, v_ang, 'conflict rezervari');
    fail('NU a respins (ar fi trebuit ORA-20011).');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20011 THEN ok('Respins corect: '||SQLERRM);
      ELSE fail('Eroare diferita: '||SQLERRM);
      END IF;
  END;

  -- (2) conflict planificare vs alt eveniment (astept ORA-20010)
  DBMS_OUTPUT.PUT_LINE('--- (2) Conflict cu ALT EVENIMENT (astept ORA-20010) ---');

  INSERT INTO Evenimente (tip_eveniment, data_eveniment, numar_persoane)
  VALUES ('TEST', DATE '2026-02-12', 5)
  RETURNING id_eveniment INTO v_evt_B1;

  INSERT INTO Evenimente (tip_eveniment, data_eveniment, numar_persoane)
  VALUES ('TEST', DATE '2026-02-12', 5)
  RETURNING id_eveniment INTO v_evt_B2;

  -- prima planificare OK
  INSERT INTO Planificari_organizatorice (id_eveniment, id_sala, id_angajat, observatii)
  VALUES (v_evt_B1, v_sala, v_ang, 'primul eveniment');

  -- a doua planificare trebuie respinsa
  BEGIN
    INSERT INTO Planificari_organizatorice (id_eveniment, id_sala, id_angajat, observatii)
    VALUES (v_evt_B2, v_sala, v_ang, 'al doilea eveniment');
    fail('NU a respins (ar fi trebuit ORA-20010).');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20010 THEN ok('Respins corect: '||SQLERRM);
      ELSE fail('Eroare diferita: '||SQLERRM);
      END IF;
  END;

  ROLLBACK TO sp10;
  DBMS_OUTPUT.PUT_LINE('============== FINAL TEST TRIGGER 10 (rollback) ==============');
END;
/

-- 11.)

SET SERVEROUTPUT ON;

DECLARE
  v_sala   NUMBER;
  v_ang    NUMBER;
  v_cli1   NUMBER;
  v_cli2   NUMBER;
  v_evt    NUMBER;
  v_rez_ok NUMBER;

  PROCEDURE ok(p_msg VARCHAR2) IS BEGIN DBMS_OUTPUT.PUT_LINE('  [OK] '||p_msg); END;
  PROCEDURE fail(p_msg VARCHAR2) IS BEGIN DBMS_OUTPUT.PUT_LINE('  [FAIL] '||p_msg); END;

BEGIN
  DBMS_OUTPUT.PUT_LINE('================= TEST TRIGGER 11 (ROW - conflict eveniment) =================');
  SAVEPOINT sp11;

  -- setup minim
  INSERT INTO Sali (nume_sala, capacitate)
  VALUES ('Sala_T11', 10)
  RETURNING id_sala INTO v_sala;

  INSERT INTO Angajati (nume, prenume, functie, salariu, mail)
  VALUES ('Test', 'Ang_T11', 'Chelner', 3000, 't11_ang_'||TO_CHAR(SYSTIMESTAMP,'YYYYMMDDHH24MISSFF3')||'@ex.com')
  RETURNING id_angajat INTO v_ang;

  INSERT INTO Clienti (nume, prenume, nr_tel, mail)
  VALUES ('Test', 'Client1_T11', '0700000000', 't11_c1_'||TO_CHAR(SYSTIMESTAMP,'YYYYMMDDHH24MISSFF3')||'@ex.com')
  RETURNING id_client INTO v_cli1;

  INSERT INTO Clienti (nume, prenume, nr_tel, mail)
  VALUES ('Test', 'Client2_T11', '0711111111', 't11_c2_'||TO_CHAR(SYSTIMESTAMP,'YYYYMMDDHH24MISSFF3')||'@ex.com')
  RETURNING id_client INTO v_cli2;

  -- Cream un eveniment pe 2026-02-15 in sala v_sala
  INSERT INTO Evenimente (tip_eveniment, data_eveniment, numar_persoane)
  VALUES ('TEST', DATE '2026-02-15', 8)
  RETURNING id_eveniment INTO v_evt;

  INSERT INTO Planificari_organizatorice (id_eveniment, id_sala, id_angajat, observatii)
  VALUES (v_evt, v_sala, v_ang, 'blocare rezervari');

  -- (1) rezervare respinsa din cauza evenimentului (astept ORA-20021)
  DBMS_OUTPUT.PUT_LINE('--- (1) Conflict cu EVENIMENT (astept ORA-20021) ---');
  BEGIN
    INSERT INTO Rezervari (data_rezervare, ora_rezervare, numar_persoane, id_client, id_sala)
    VALUES (DATE '2026-02-15', '19:00', 2, v_cli1, v_sala);

    fail('NU a respins (ar fi trebuit ORA-20021).');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20021 THEN ok('Respins corect: '||SQLERRM);
      ELSE fail('Eroare diferita: '||SQLERRM);
      END IF;
  END;

  -- (2) rezervare OK intr-o zi fara eveniment
  DBMS_OUTPUT.PUT_LINE('--- (2) Rezervare OK (fara eveniment) ---');
  BEGIN
    INSERT INTO Rezervari (data_rezervare, ora_rezervare, numar_persoane, id_client, id_sala)
    VALUES (DATE '2026-02-20', '18:00', 3, v_cli1, v_sala)
    RETURNING id_rezervare INTO v_rez_ok;

    ok('Inserare reusita (id_rezervare='||v_rez_ok||').');
  EXCEPTION
    WHEN OTHERS THEN
      fail('NU ar fi trebuit sa dea eroare: '||SQLERRM);
  END;

  -- (3) UPDATE catre o zi cu eveniment (astept ORA-20021)
  DBMS_OUTPUT.PUT_LINE('--- (3) UPDATE catre zi cu eveniment (astept ORA-20021) ---');
  BEGIN
    UPDATE Rezervari
    SET data_rezervare = DATE '2026-02-15'
    WHERE id_rezervare = v_rez_ok;

    fail('NU a respins UPDATE-ul (ar fi trebuit ORA-20021).');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20021 THEN ok('Respins corect la UPDATE: '||SQLERRM);
      ELSE fail('Eroare diferita: '||SQLERRM);
      END IF;
  END;

  ROLLBACK TO sp11;
  DBMS_OUTPUT.PUT_LINE('============== FINAL TEST TRIGGER 11 (rollback) ==============');
END;
/



-- 12.) 

SET SERVEROUTPUT ON;

DECLARE
  PROCEDURE ok(p VARCHAR2)   IS BEGIN DBMS_OUTPUT.PUT_LINE('  [OK] '||p); END;
  PROCEDURE fail(p VARCHAR2) IS BEGIN DBMS_OUTPUT.PUT_LINE('  [FAIL] '||p); END;
BEGIN

  DBMS_OUTPUT.PUT_LINE('================= TEST CERINTA 12 (AUDIT + GUARD) =================');

  DBMS_OUTPUT.PUT_LINE('--- (0) NU ai voie sa adaugi AUDIT_DDL in GUARD_LDD (astept ORA-02290) ---');
  BEGIN
    INSERT INTO guard_ldd(obj_type, obj_name, block_drop) VALUES ('TABLE','AUDIT_DDL','Y');
    fail('A permis inserarea AUDIT_DDL in GUARD_LDD.');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -2290 THEN ok('Blocare corecta (check constraint): '||SQLERRM);
      ELSE fail('Eroare diferita: '||SQLERRM);
      END IF;
  END;
  ROLLBACK;

  DBMS_OUTPUT.PUT_LINE('--- (0b) NU ai voie sa adaugi GUARD_LDD in GUARD_LDD (astept ORA-02290) ---');
  BEGIN
    INSERT INTO guard_ldd(obj_type, obj_name, block_drop) VALUES ('TABLE','GUARD_LDD','Y');
    fail('A permis inserarea GUARD_LDD in GUARD_LDD.');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -2290 THEN ok('Blocare corecta (check constraint): '||SQLERRM);
      ELSE fail('Eroare diferita: '||SQLERRM);
      END IF;
  END;
  ROLLBACK;

  -- Curatam (daca exista) tabela de test
  BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE t_guard_test PURGE';
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  DBMS_OUTPUT.PUT_LINE('--- (1) CREATE TABLE t_guard_test (trebuie sa mearga) ---');
  BEGIN
    EXECUTE IMMEDIATE 'CREATE TABLE t_guard_test (id NUMBER)';
    ok('CREATE TABLE reusit.');
  EXCEPTION
    WHEN OTHERS THEN fail('Nu trebuia eroare: '||SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('--- (2) Protejam tabela (block_drop=Y) ---');
  INSERT INTO guard_ldd(obj_type, obj_name, active, block_drop, block_truncate, block_alter, reason)
  VALUES ('TABLE','T_GUARD_TEST','Y','Y','N','N','Test protectie DROP');
  COMMIT;
  ok('Regula GUARD_LDD inserata.');

  DBMS_OUTPUT.PUT_LINE('--- (3) DROP TABLE protejat (astept ORA-20050) ---');
  BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE t_guard_test PURGE';
    fail('NU trebuia sa permita DROP (era protejata).');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -20050 THEN ok('Blocare corecta: '||SQLERRM);
      ELSE 
        IF INSTR(DBMS_UTILITY.FORMAT_ERROR_STACK, 'ORA-20050') > 0 THEN
        ok('Blocare corecta: ORA-20050 apare in stack (e wrapped in alte exceptii).');
        ELSE
          fail('Eroare diferita: '||SQLERRM);
          DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_ERROR_STACK);
        END IF;
      END IF;
  END;

  DBMS_OUTPUT.PUT_LINE('--- (4) Dezactivam protectia si incercam din nou DROP (trebuie sa mearga) ---');
  UPDATE guard_ldd
  SET active='N'
  WHERE obj_type='TABLE' AND obj_name='T_GUARD_TEST';
  COMMIT;

  BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE t_guard_test PURGE';
    ok('DROP TABLE reusit dupa dezactivarea guard.');
  EXCEPTION
    WHEN OTHERS THEN fail('Nu trebuia eroare: '||SQLERRM);
  END;

  DBMS_OUTPUT.PUT_LINE('--- (5) Ultimele intrari din AUDIT_DDL (top 10) ---');
  FOR r IN (
    SELECT id, event_time, ddl_event, object_type, object_name, db_user
    FROM audit_ddl
    ORDER BY id DESC
    FETCH FIRST 10 ROWS ONLY
  ) LOOP
    DBMS_OUTPUT.PUT_LINE('   #'||r.id||' | '||
      TO_CHAR(r.event_time,'YYYY-MM-DD HH24:MI:SS')||' | '||
      r.ddl_event||' | '||r.object_type||' '||r.object_name||' | '||r.db_user);
  END LOOP;
  
  DBMS_OUTPUT.PUT_LINE('--- (6) SEQUENCE + DROP ---');

  BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_guard_test'; EXCEPTION WHEN OTHERS THEN NULL; END;
  DELETE FROM guard_ldd WHERE obj_type='SEQUENCE' AND obj_name='SEQ_GUARD_TEST';

  EXECUTE IMMEDIATE 'CREATE SEQUENCE seq_guard_test START WITH 1 INCREMENT BY 1';

  INSERT INTO guard_ldd(obj_type, obj_name, active, block_drop, block_truncate, block_alter, reason)
  VALUES ('SEQUENCE','SEQ_GUARD_TEST','Y','Y','N','N','Seq DROP blocat');
  COMMIT;

  BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_guard_test';
    fail('(6.a) NU trebuia sa permita DROP SEQUENCE.');
  EXCEPTION
    WHEN OTHERS THEN
      IF INSTR(DBMS_UTILITY.FORMAT_ERROR_STACK,'ORA-20050')>0 THEN
        ok('(6.a) Blocare corecta (ORA-20050 in stack).');
      ELSE
        fail('(6.a) Eroare diferita: '||SQLERRM);
        DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_ERROR_STACK);
      END IF;
  END;

  UPDATE guard_ldd SET active='N'
  WHERE obj_type='SEQUENCE' AND obj_name='SEQ_GUARD_TEST';
  COMMIT;

  BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_guard_test';
    ok('(6.b) DROP permis corect (active=N).');
  EXCEPTION
    WHEN OTHERS THEN fail('(6.b) DROP trebuia sa mearga: '||SQLERRM);
  END;

  EXECUTE IMMEDIATE 'CREATE SEQUENCE seq_guard_test START WITH 1 INCREMENT BY 1';

  UPDATE guard_ldd SET active='Y', block_drop='N'
  WHERE obj_type='SEQUENCE' AND obj_name='SEQ_GUARD_TEST';
  COMMIT;

  BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_guard_test';
    ok('(6.c) DROP permis corect (block_drop=N).');
  EXCEPTION
    WHEN OTHERS THEN fail('(6.c) DROP trebuia sa mearga: '||SQLERRM);
  END;

  DELETE FROM guard_ldd WHERE obj_type='SEQUENCE' AND obj_name='SEQ_GUARD_TEST';
  COMMIT;


  DBMS_OUTPUT.PUT_LINE('--- (7) SEQUENCE + ALTER ---');

  BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_guard_alter'; EXCEPTION WHEN OTHERS THEN NULL; END;
  DELETE FROM guard_ldd WHERE obj_type='SEQUENCE' AND obj_name='SEQ_GUARD_ALTER';

  EXECUTE IMMEDIATE 'CREATE SEQUENCE seq_guard_alter START WITH 1 INCREMENT BY 1';

  INSERT INTO guard_ldd(obj_type, obj_name, active, block_drop, block_truncate, block_alter, reason)
  VALUES ('SEQUENCE','SEQ_GUARD_ALTER','Y','N','N','Y','Seq ALTER blocat');
  COMMIT;

  BEGIN
    EXECUTE IMMEDIATE 'ALTER SEQUENCE seq_guard_alter INCREMENT BY 5';
    fail('(7.a) NU trebuia sa permita ALTER SEQUENCE.');
  EXCEPTION
    WHEN OTHERS THEN
      IF INSTR(DBMS_UTILITY.FORMAT_ERROR_STACK,'ORA-20052')>0 THEN
        ok('(7.a) Blocare corecta (ORA-20052 in stack).');
      ELSE
        fail('(7.a) Eroare diferita: '||SQLERRM);
        DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_ERROR_STACK);
      END IF;
  END;

  UPDATE guard_ldd SET active='N'
  WHERE obj_type='SEQUENCE' AND obj_name='SEQ_GUARD_ALTER';
  COMMIT;

  BEGIN
    EXECUTE IMMEDIATE 'ALTER SEQUENCE seq_guard_alter INCREMENT BY 5';
    ok('(7.b) ALTER permis corect (active=N).');
  EXCEPTION
    WHEN OTHERS THEN fail('(7.b) ALTER trebuia sa mearga: '||SQLERRM);
  END;

  UPDATE guard_ldd SET active='Y', block_alter='N'
  WHERE obj_type='SEQUENCE' AND obj_name='SEQ_GUARD_ALTER';
  COMMIT;

  BEGIN
    EXECUTE IMMEDIATE 'ALTER SEQUENCE seq_guard_alter INCREMENT BY 2';
    ok('(7.c) ALTER permis corect (block_alter=N).');
  EXCEPTION
    WHEN OTHERS THEN fail('(7.c) ALTER trebuia sa mearga: '||SQLERRM);
  END;

  BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_guard_alter'; EXCEPTION WHEN OTHERS THEN NULL; END;
  DELETE FROM guard_ldd WHERE obj_type='SEQUENCE' AND obj_name='SEQ_GUARD_ALTER';
  COMMIT;


  DBMS_OUTPUT.PUT_LINE('--- (8) VIEW + DROP ---');

  BEGIN EXECUTE IMMEDIATE 'DROP VIEW v_guard_test'; EXCEPTION WHEN OTHERS THEN NULL; END;
  DELETE FROM guard_ldd WHERE obj_type='VIEW' AND obj_name='V_GUARD_TEST';

  EXECUTE IMMEDIATE 'CREATE OR REPLACE VIEW v_guard_test AS SELECT 1 AS x FROM dual';

  INSERT INTO guard_ldd(obj_type, obj_name, active, block_drop, block_truncate, block_alter, reason)
  VALUES ('VIEW','V_GUARD_TEST','Y','Y','N','N','View DROP blocat');
  COMMIT;

  BEGIN
    EXECUTE IMMEDIATE 'DROP VIEW v_guard_test';
    fail('(8.a) NU trebuia sa permita DROP VIEW.');
  EXCEPTION
    WHEN OTHERS THEN
      IF INSTR(DBMS_UTILITY.FORMAT_ERROR_STACK,'ORA-20050')>0 THEN
        ok('(8.a) Blocare corecta (ORA-20050 in stack).');
      ELSE
        fail('(8.a) Eroare diferita: '||SQLERRM);
        DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_ERROR_STACK);
      END IF;
  END;

  UPDATE guard_ldd SET active='N'
  WHERE obj_type='VIEW' AND obj_name='V_GUARD_TEST';
  COMMIT;

  BEGIN
    EXECUTE IMMEDIATE 'DROP VIEW v_guard_test';
    ok('(8.b) DROP permis corect (active=N).');
  EXCEPTION
    WHEN OTHERS THEN fail('(8.b) DROP trebuia sa mearga: '||SQLERRM);
  END;

  EXECUTE IMMEDIATE 'CREATE OR REPLACE VIEW v_guard_test AS SELECT 1 AS x FROM dual';

  UPDATE guard_ldd SET active='Y', block_drop='N'
  WHERE obj_type='VIEW' AND obj_name='V_GUARD_TEST';
  COMMIT;

  BEGIN
    EXECUTE IMMEDIATE 'DROP VIEW v_guard_test';
    ok('(8.c) DROP permis corect (block_drop=N).');
  EXCEPTION
    WHEN OTHERS THEN fail('(8.c) DROP trebuia sa mearga: '||SQLERRM);
  END;

  DELETE FROM guard_ldd WHERE obj_type='VIEW' AND obj_name='V_GUARD_TEST';
  COMMIT;
  
  DBMS_OUTPUT.PUT_LINE('--- (5) Ultimele intrari din AUDIT_DDL (top 20) ---');
  FOR r IN (
    SELECT id, event_time, ddl_event, object_type, object_name, db_user
    FROM audit_ddl
    ORDER BY id DESC
    FETCH FIRST 20 ROWS ONLY
  ) LOOP
    DBMS_OUTPUT.PUT_LINE('   #'||r.id||' | '||
      TO_CHAR(r.event_time,'YYYY-MM-DD HH24:MI:SS')||' | '||
      r.ddl_event||' | '||r.object_type||' '||r.object_name||' | '||r.db_user);
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('================= FINAL TEST CERINTA 12 =================');

END;
/
