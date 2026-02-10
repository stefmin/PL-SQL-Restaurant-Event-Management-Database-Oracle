-- ============================================================
-- Inserare date coerente - schema ERD simplificata (Oracle)
-- 7 randuri pentru fiecare tabela de baza; 12 pentru asociative
-- ============================================================
SET DEFINE OFF;

-- =========================
-- ANGAJATI (7)
-- =========================
INSERT INTO Angajati (id_angajat, nume, prenume, functie, salariu, data_angajare, mail) VALUES (101, 'Popescu', 'Andrei', 'Manager', 7500, DATE '2024-03-15', 'andrei.popescu@BellaIta.ro');
INSERT INTO Angajati (id_angajat, nume, prenume, functie, salariu, data_angajare, mail) VALUES (102, 'Ionescu', 'Maria', 'Chelner', 4200, DATE '2024-06-01', 'maria.ionescu@BellaIta.ro');
INSERT INTO Angajati (id_angajat, nume, prenume, functie, salariu, data_angajare, mail) VALUES (103, 'Dumitru', 'Vlad', 'Bucatar', 5200, DATE '2023-11-10', 'vlad.dumitru@BellaIta.ro');
INSERT INTO Angajati (id_angajat, nume, prenume, functie, salariu, data_angajare, mail) VALUES (104, 'Stan', 'Ioana', 'Barman', 4500, DATE '2024-02-20', 'ioana.stan@BellaIta.ro');
INSERT INTO Angajati (id_angajat, nume, prenume, functie, salariu, data_angajare, mail) VALUES (105, 'Georgescu', 'Radu', 'Host', 3800, DATE '2024-09-05', 'radu.georgescu@BellaIta.ro');
INSERT INTO Angajati (id_angajat, nume, prenume, functie, salariu, data_angajare, mail) VALUES (106, 'Marin', 'Elena', 'Coordonator evenimente', 6000, DATE '2023-07-12', 'elena.marin@BellaIta.ro');
INSERT INTO Angajati (id_angajat, nume, prenume, functie, salariu, data_angajare, mail) VALUES (107, 'Toma', 'Mihai', 'Curier', 3600, DATE '2024-01-08', 'mihai.toma@BellaIta.ro');

-- =========================
-- CLIENTI (7)
-- =========================
INSERT INTO Clienti (id_client, nume, prenume, nr_tel, mail) VALUES (201, 'Popa', 'Ana', '0711001100', 'ana.popa@gmail.com');
INSERT INTO Clienti (id_client, nume, prenume, nr_tel, mail) VALUES (202, 'Rusu', 'Bogdan', '0722002200', 'bogdan.rusu@gmail.com');
INSERT INTO Clienti (id_client, nume, prenume, nr_tel, mail) VALUES (203, 'Munteanu', 'Ioana', '0733003300', 'ioana.munteanu@gmail.com');
INSERT INTO Clienti (id_client, nume, prenume, nr_tel, mail) VALUES (204, 'Ilie', 'Cristian', '0744004400', 'cristian.ilie@gmail.com');
INSERT INTO Clienti (id_client, nume, prenume, nr_tel, mail) VALUES (205, 'Sandu', 'Daria', '0755005500', 'daria.sandu@gmail.com');
INSERT INTO Clienti (id_client, nume, prenume, nr_tel, mail) VALUES (206, 'Lazar', 'Paul', '0766006600', 'paul.lazar@gmail.com');
INSERT INTO Clienti (id_client, nume, prenume, nr_tel, mail) VALUES (207, 'Neagu', 'Teodora', '0777007700', 'teodora.neagu@gmail.com');

-- =========================
-- SALI (7)
-- =========================
INSERT INTO Sali (id_sala, nume_sala, capacitate) VALUES (301, 'Sala Mare', 200);
INSERT INTO Sali (id_sala, nume_sala, capacitate) VALUES (302, 'Sala VIP', 60);
INSERT INTO Sali (id_sala, nume_sala, capacitate) VALUES (303, 'Terasa', 120);
INSERT INTO Sali (id_sala, nume_sala, capacitate) VALUES (304, 'Salon Rustic', 80);
INSERT INTO Sali (id_sala, nume_sala, capacitate) VALUES (305, 'Sala Conferinte', 100);
INSERT INTO Sali (id_sala, nume_sala, capacitate) VALUES (306, 'Salon Family', 40);
INSERT INTO Sali (id_sala, nume_sala, capacitate) VALUES (307, 'Gradina', 150);

-- =========================
-- EVENIMENTE (7)
-- =========================
INSERT INTO Evenimente (id_eveniment, tip_eveniment, data_eveniment, numar_persoane) VALUES (401, 'nunta', DATE '2026-02-14', 150);
INSERT INTO Evenimente (id_eveniment, tip_eveniment, data_eveniment, numar_persoane) VALUES (402, 'botez', DATE '2026-01-25', 60);
INSERT INTO Evenimente (id_eveniment, tip_eveniment, data_eveniment, numar_persoane) VALUES (403, 'corporate', DATE '2026-03-05', 90);
INSERT INTO Evenimente (id_eveniment, tip_eveniment, data_eveniment, numar_persoane) VALUES (404, 'aniversare', DATE '2026-01-18', 30);
INSERT INTO Evenimente (id_eveniment, tip_eveniment, data_eveniment, numar_persoane) VALUES (405, 'petrecere copii', DATE '2026-02-01', 45);
INSERT INTO Evenimente (id_eveniment, tip_eveniment, data_eveniment, numar_persoane) VALUES (406, 'majorat', DATE '2026-02-21', 70);
INSERT INTO Evenimente (id_eveniment, tip_eveniment, data_eveniment, numar_persoane) VALUES (407, 'team building', DATE '2026-03-20', 110);

-- =========================
-- ANIMATORI (7)
-- =========================
INSERT INTO Animatori (id_animator, nume_animator, tip_activitate, pret_ora) VALUES (501, 'Dinu Ion', 'DJ', 300);
INSERT INTO Animatori (id_animator, nume_animator, tip_activitate, pret_ora) VALUES (502, 'Popescu Marcel', 'Magician', 450);
INSERT INTO Animatori (id_animator, nume_animator, tip_activitate, pret_ora) VALUES (503, 'Mocanu Alina', 'Animatoare copii', 250);
INSERT INTO Animatori (id_animator, nume_animator, tip_activitate, pret_ora) VALUES (504, 'Aleandru Tudor', 'Prezentatoare', 350);
INSERT INTO Animatori (id_animator, nume_animator, tip_activitate, pret_ora) VALUES (505, 'Ionescu Roxana', 'Lider echipa dansatori', 500);
INSERT INTO Animatori (id_animator, nume_animator, tip_activitate, pret_ora) VALUES (506, 'Ciubotaru Vlad', 'Fotograf', 400);
INSERT INTO Animatori (id_animator, nume_animator, tip_activitate, pret_ora) VALUES (507, 'Lungu Sorin', 'Lider trupa live', 650);

-- =========================
-- OFERTE (7)
-- =========================
INSERT INTO Oferte (id_oferta, discount, data_expirare) VALUES (601, 10, DATE '2026-03-31');
INSERT INTO Oferte (id_oferta, discount, data_expirare) VALUES (602, 15, DATE '2026-02-28');
INSERT INTO Oferte (id_oferta, discount, data_expirare) VALUES (603, 20, DATE '2026-01-31');
INSERT INTO Oferte (id_oferta, discount, data_expirare) VALUES (604, 5, DATE '2026-04-30');
INSERT INTO Oferte (id_oferta, discount, data_expirare) VALUES (605, 12.5, DATE '2026-03-15');
INSERT INTO Oferte (id_oferta, discount, data_expirare) VALUES (606, 25, DATE '2026-02-15');
INSERT INTO Oferte (id_oferta, discount, data_expirare) VALUES (607, 8, DATE '2026-05-31');

-- =========================
-- PRODUSE (7)
-- =========================
INSERT INTO Produse (id_produs, nume_produs, cantitate, unitate_masura, pret_unitar) VALUES (701, 'Pizza Margherita', 400, 'portie', 32.5);
INSERT INTO Produse (id_produs, nume_produs, cantitate, unitate_masura, pret_unitar) VALUES (702, 'Paste Carbonara', 200, 'portie', 38.0);
INSERT INTO Produse (id_produs, nume_produs, cantitate, unitate_masura, pret_unitar) VALUES (703, 'Apa plata 0.5L', 500, 'sticla', 8.5);
INSERT INTO Produse (id_produs, nume_produs, cantitate, unitate_masura, pret_unitar) VALUES (704, 'Suc natural', 250, 'pahar', 12.0);
INSERT INTO Produse (id_produs, nume_produs, cantitate, unitate_masura, pret_unitar) VALUES (705, 'Bere draft', 400, 'pahar', 10.0);
INSERT INTO Produse (id_produs, nume_produs, cantitate, unitate_masura, pret_unitar) VALUES (706, 'Desert Tiramisu', 150, 'portie', 22.0);
INSERT INTO Produse (id_produs, nume_produs, cantitate, unitate_masura, pret_unitar) VALUES (707, 'Cafea espresso', 40, 'buc', 9.0);

-- =========================
-- REZERVARI (7)
-- =========================

-- Obs: nu are trigger pentru verificarea datei pentru motive de compatibilitate/eroare umana. Se pot introduce rezervari care au avut loc mai demult de catre angajati.
INSERT INTO Rezervari (id_rezervare, data_rezervare, ora_rezervare, numar_persoane, id_client, id_sala) VALUES (801, DATE '2026-01-10', '18:30', 4, 201, 306);
INSERT INTO Rezervari (id_rezervare, data_rezervare, ora_rezervare, numar_persoane, id_client, id_sala) VALUES (802, DATE '2026-01-11', '20:00', 2, 202, 302);
INSERT INTO Rezervari (id_rezervare, data_rezervare, ora_rezervare, numar_persoane, id_client, id_sala) VALUES (803, DATE '2026-01-12', '19:15', 6, 203, 301);
INSERT INTO Rezervari (id_rezervare, data_rezervare, ora_rezervare, numar_persoane, id_client, id_sala) VALUES (804, DATE '2026-01-13', '13:00', 3, 204, 304);
INSERT INTO Rezervari (id_rezervare, data_rezervare, ora_rezervare, numar_persoane, id_client, id_sala) VALUES (805, DATE '2026-01-14', '21:45', 5, 205, 303);
INSERT INTO Rezervari (id_rezervare, data_rezervare, ora_rezervare, numar_persoane, id_client, id_sala) VALUES (806, DATE '2026-01-15', '18:00', 2, 206, 302);
INSERT INTO Rezervari (id_rezervare, data_rezervare, ora_rezervare, numar_persoane, id_client, id_sala) VALUES (807, DATE '2026-01-16', '12:30', 8, 207, 307);

-- =========================
-- COMENZI (7)  
-- =========================
INSERT INTO Comenzi (id_comanda, data_comanda, status, id_client) VALUES (901, DATE '2026-01-10', 'plasata', 201);
INSERT INTO Comenzi (id_comanda, data_comanda, status, id_client) VALUES (902, DATE '2026-01-10', 'in curs de preparare', 202);
INSERT INTO Comenzi (id_comanda, data_comanda, status, id_client) VALUES (903, DATE '2026-01-11', 'platita', 203);
INSERT INTO Comenzi (id_comanda, data_comanda, status, id_client) VALUES (904, DATE '2026-01-11', 'plasata', 204);
INSERT INTO Comenzi (id_comanda, data_comanda, status, id_client) VALUES (905, DATE '2026-01-12', 'anulata', 205);
INSERT INTO Comenzi (id_comanda, data_comanda, status, id_client) VALUES (906, DATE '2026-01-12', 'platita', 206);
INSERT INTO Comenzi (id_comanda, data_comanda, status, id_client) VALUES (907, DATE '2026-01-13', 'plasata', 207);

-- =========================
-- COMENZI_PRODUSE (12)
-- =========================
INSERT INTO Comenzi_Produse (id_comanda, id_produs, cantitate) VALUES (901, 701, 2);
INSERT INTO Comenzi_Produse (id_comanda, id_produs, cantitate) VALUES (901, 703, 2);
INSERT INTO Comenzi_Produse (id_comanda, id_produs, cantitate) VALUES (902, 702, 1);
INSERT INTO Comenzi_Produse (id_comanda, id_produs, cantitate) VALUES (902, 705, 2);
INSERT INTO Comenzi_Produse (id_comanda, id_produs, cantitate) VALUES (903, 706, 2);
INSERT INTO Comenzi_Produse (id_comanda, id_produs, cantitate) VALUES (903, 707, 2);
INSERT INTO Comenzi_Produse (id_comanda, id_produs, cantitate) VALUES (904, 701, 1);
INSERT INTO Comenzi_Produse (id_comanda, id_produs, cantitate) VALUES (904, 704, 2);
INSERT INTO Comenzi_Produse (id_comanda, id_produs, cantitate) VALUES (905, 702, 1);
INSERT INTO Comenzi_Produse (id_comanda, id_produs, cantitate) VALUES (905, 703, 1);
INSERT INTO Comenzi_Produse (id_comanda, id_produs, cantitate) VALUES (906, 701, 3);
INSERT INTO Comenzi_Produse (id_comanda, id_produs, cantitate) VALUES (907, 707, 2);

-- =========================
-- COMENZI_ANGAJATI (12)
-- =========================
INSERT INTO Comenzi_Angajati (id_comanda, id_angajat) VALUES (901, 102);
INSERT INTO Comenzi_Angajati (id_comanda, id_angajat) VALUES (901, 103);
INSERT INTO Comenzi_Angajati (id_comanda, id_angajat) VALUES (902, 102);
INSERT INTO Comenzi_Angajati (id_comanda, id_angajat) VALUES (902, 104);
INSERT INTO Comenzi_Angajati (id_comanda, id_angajat) VALUES (903, 102);
INSERT INTO Comenzi_Angajati (id_comanda, id_angajat) VALUES (903, 103);
INSERT INTO Comenzi_Angajati (id_comanda, id_angajat) VALUES (904, 105);
INSERT INTO Comenzi_Angajati (id_comanda, id_angajat) VALUES (904, 103);
INSERT INTO Comenzi_Angajati (id_comanda, id_angajat) VALUES (905, 102);
INSERT INTO Comenzi_Angajati (id_comanda, id_angajat) VALUES (906, 104);
INSERT INTO Comenzi_Angajati (id_comanda, id_angajat) VALUES (906, 102);
INSERT INTO Comenzi_Angajati (id_comanda, id_angajat) VALUES (907, 107);

-- =========================
-- LISTE_REDUCERI (12)
-- =========================
INSERT INTO Liste_reduceri (id_oferta, id_produs) VALUES (601, 701);
INSERT INTO Liste_reduceri (id_oferta, id_produs) VALUES (601, 702);
INSERT INTO Liste_reduceri (id_oferta, id_produs) VALUES (602, 703);
INSERT INTO Liste_reduceri (id_oferta, id_produs) VALUES (602, 704);
INSERT INTO Liste_reduceri (id_oferta, id_produs) VALUES (603, 705);
INSERT INTO Liste_reduceri (id_oferta, id_produs) VALUES (603, 706);
INSERT INTO Liste_reduceri (id_oferta, id_produs) VALUES (604, 707);
INSERT INTO Liste_reduceri (id_oferta, id_produs) VALUES (605, 701);
INSERT INTO Liste_reduceri (id_oferta, id_produs) VALUES (605, 706);
INSERT INTO Liste_reduceri (id_oferta, id_produs) VALUES (606, 702);
INSERT INTO Liste_reduceri (id_oferta, id_produs) VALUES (606, 705);
INSERT INTO Liste_reduceri (id_oferta, id_produs) VALUES (607, 703);

-- =========================
-- EVENIMENTE_PRODUSE (12)
-- =========================
INSERT INTO Evenimente_Produse (id_eveniment, id_produs, cantitate) VALUES (401, 703, 150);
INSERT INTO Evenimente_Produse (id_eveniment, id_produs, cantitate) VALUES (401, 705, 120);
INSERT INTO Evenimente_Produse (id_eveniment, id_produs, cantitate) VALUES (402, 703, 60);
INSERT INTO Evenimente_Produse (id_eveniment, id_produs, cantitate) VALUES (402, 706, 40);
INSERT INTO Evenimente_Produse (id_eveniment, id_produs, cantitate) VALUES (403, 703, 90);
INSERT INTO Evenimente_Produse (id_eveniment, id_produs, cantitate) VALUES (403, 704, 80);
INSERT INTO Evenimente_Produse (id_eveniment, id_produs, cantitate) VALUES (404, 701, 20);
INSERT INTO Evenimente_Produse (id_eveniment, id_produs, cantitate) VALUES (404, 707, 25);
INSERT INTO Evenimente_Produse (id_eveniment, id_produs, cantitate) VALUES (405, 704, 60);
INSERT INTO Evenimente_Produse (id_eveniment, id_produs, cantitate) VALUES (406, 705, 90);
INSERT INTO Evenimente_Produse (id_eveniment, id_produs, cantitate) VALUES (406, 706, 50);
INSERT INTO Evenimente_Produse (id_eveniment, id_produs, cantitate) VALUES (407, 703, 110);

-- =========================
-- COLABORARI (12)
-- =========================
INSERT INTO Colaborari (id_eveniment, id_animator, numar_ore) VALUES (401, 501, 6);
INSERT INTO Colaborari (id_eveniment, id_animator, numar_ore) VALUES (401, 504, 6);
INSERT INTO Colaborari (id_eveniment, id_animator, numar_ore) VALUES (402, 506, 4);
INSERT INTO Colaborari (id_eveniment, id_animator, numar_ore) VALUES (403, 507, 5);
INSERT INTO Colaborari (id_eveniment, id_animator, numar_ore) VALUES (404, 502, 2);
INSERT INTO Colaborari (id_eveniment, id_animator, numar_ore) VALUES (405, 503, 4);
INSERT INTO Colaborari (id_eveniment, id_animator, numar_ore) VALUES (406, 501, 5);
INSERT INTO Colaborari (id_eveniment, id_animator, numar_ore) VALUES (406, 505, 3);
INSERT INTO Colaborari (id_eveniment, id_animator, numar_ore) VALUES (407, 504, 4);
INSERT INTO Colaborari (id_eveniment, id_animator, numar_ore) VALUES (403, 506, 4);
INSERT INTO Colaborari (id_eveniment, id_animator, numar_ore) VALUES (402, 503, 3);
INSERT INTO Colaborari (id_eveniment, id_animator, numar_ore) VALUES (407, 507, 6);

-- =========================
-- PARTICIPARI_EVENIMENTE (12)
-- =========================
INSERT INTO Participari_evenimente (id_eveniment, id_client) VALUES (401, 201);
INSERT INTO Participari_evenimente (id_eveniment, id_client) VALUES (401, 202);
INSERT INTO Participari_evenimente (id_eveniment, id_client) VALUES (402, 203);
INSERT INTO Participari_evenimente (id_eveniment, id_client) VALUES (402, 204);
INSERT INTO Participari_evenimente (id_eveniment, id_client) VALUES (403, 205);
INSERT INTO Participari_evenimente (id_eveniment, id_client) VALUES (403, 206);
INSERT INTO Participari_evenimente (id_eveniment, id_client) VALUES (404, 207);
INSERT INTO Participari_evenimente (id_eveniment, id_client) VALUES (405, 201);
INSERT INTO Participari_evenimente (id_eveniment, id_client) VALUES (405, 203);
INSERT INTO Participari_evenimente (id_eveniment, id_client) VALUES (406, 202);
INSERT INTO Participari_evenimente (id_eveniment, id_client) VALUES (406, 204);
INSERT INTO Participari_evenimente (id_eveniment, id_client) VALUES (407, 206);

-- =========================
-- PLANIFICARI_ORGANIZATORICE (12)
-- =========================
INSERT INTO Planificari_organizatorice (id_angajat, id_eveniment, id_sala, observatii) VALUES (102, 401, 301, 'servire sala mare');
INSERT INTO Planificari_organizatorice (id_angajat, id_eveniment, id_sala, observatii) VALUES (103, 401, 301, 'coordonare meniu');
INSERT INTO Planificari_organizatorice (id_angajat, id_eveniment, id_sala, observatii) VALUES (106, 401, 301, 'organizare generala');
INSERT INTO Planificari_organizatorice (id_angajat, id_eveniment, id_sala, observatii) VALUES (105, 402, 302, 'primire invitati');
INSERT INTO Planificari_organizatorice (id_angajat, id_eveniment, id_sala, observatii) VALUES (102, 403, 305, 'servire coffee break');
INSERT INTO Planificari_organizatorice (id_angajat, id_eveniment, id_sala, observatii) VALUES (106, 403, 305, 'logistica eveniment');
INSERT INTO Planificari_organizatorice (id_angajat, id_eveniment, id_sala, observatii) VALUES (104, 404, 304, 'bar eveniment');
INSERT INTO Planificari_organizatorice (id_angajat, id_eveniment, id_sala, observatii) VALUES (103, 405, 306, 'meniu copii');
INSERT INTO Planificari_organizatorice (id_angajat, id_eveniment, id_sala, observatii) VALUES (106, 405, 306, 'management activitati');
INSERT INTO Planificari_organizatorice (id_angajat, id_eveniment, id_sala, observatii) VALUES (102, 406, 303, 'servire terasa');
INSERT INTO Planificari_organizatorice (id_angajat, id_eveniment, id_sala, observatii) VALUES (104, 406, 303, 'bar terasa');
INSERT INTO Planificari_organizatorice (id_angajat, id_eveniment, id_sala, observatii) VALUES (106, 407, 307, 'organizare outdoor');

COMMIT;