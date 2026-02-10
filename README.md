## Restaurant & Event Management Database — Oracle PL/SQL (Oracle 21c XE)

A normalized Oracle database designed to manage restaurant operations end-to-end: employees, clients, reservations, events, halls, products, offers/discounts, and the operational logistics that connect them (planning staff by hall/event, tracking participants, estimating required inventory, and controlling conflicts).

This project goes beyond schema design: it includes **PL/SQL subprograms, exception-safe reporting, LMD/LDD triggers, and an integrated package-based workflow** for stock planning and “purchase-order-like” operations driven by event demand.

### Core Domain Model (examples)
- Employees, Clients, Halls, Reservations
- Events + Participants
- Products + Offers/Discounts
- Staff planning by event & hall (including a ternary planning relationship)
- Event-to-products consumption requirements

### What’s implemented (selected highlights)

#### Advanced PL/SQL reporting & analytics
- **Logistics report for an event (`raport_logistic_eveniment`)**
  - Uses **all 3 collection types**: `VARRAY` (alerts), `NESTED TABLE` (product ids), `ASSOCIATIVE ARRAY` (product → required quantity).
  - Computes allocated hall capacity, checks participant counts, verifies stock sufficiency, estimates cost, and emits actionable alerts (e.g., insufficient stock/capacity, missing planning).  
- **Events-by-interval report (`raport_evenimente_sali`)**
  - Demonstrates 2 cursor types: an explicit cursor (`OPEN/FETCH/CLOSE`) for events and a dependent parameterized cursor for halls + planned staff counts.
- **Reservation lookup function (`f_detalii_rezervare_client_zi`)**
  - Single SQL statement joining **3 tables**, with robust exception handling including `NO_DATA_FOUND` and `TOO_MANY_ROWS`.
- **Client history procedure (`p9_raport_istoric_client`)**
  - 2 parameters + a single SQL cursor joining **5 tables**, outputs last N participated events and detailed context (capacity, planned staff, hall allocation, other participants), with custom exceptions.

#### Data integrity through triggers
- **Statement-level LMD trigger** on planning:
  - After changes to staff planning, rejects conflicts such as:
    - same hall hosting multiple events on the same day,
    - hall day collisions between events and reservations,
    - and can force rescheduling when no halls are free.
- **Row-level LMD trigger** on reservations:
  - Prevents inserting/updating a reservation into a hall that already has an event scheduled the same day (also validates hall existence).
- **DDL (LDD) auditing + protection**
  - Logs DDL operations into an audit table.
  - Supports a guard table that can block disallowed `DROP` actions for protected objects.

#### Integrated package workflow (`pkg_gestiune_stoc`)
A package implementing an end-to-end flow to decide whether to place “orders” for products needed by upcoming events:
- Analyzes demand for a reference event + demand across a configurable time horizon.
- Applies a buffer percentage (safety stock) to avoid running “at the limit”.
- Enforces **one pending order per product** (must be received or canceled before creating another).
- Receiving an order updates product stock; if stock is already sufficient, no changes are applied.
- Uses complex types (records, nested tables, associative maps) and multiple functions/procedures.

### Running the project
- Developed and tested on **Oracle Database 21c Express Edition (XE)**.
- Run the script(s) in SQL Developer / SQL*Plus:
  1. Create tables + constraints
  2. Insert sample data
  3. Compile PL/SQL procedures/functions/triggers/package
  4. Execute the included test calls (`SET SERVEROUTPUT ON`) to validate all cases

### Skills demonstrated
Oracle modeling (3NF), constraints, bulk operations, cursor patterns, exception design, trigger-based integrity enforcement, and package-driven transactional workflows.
