"""
Direct verification of MySQL 8.4 LTS Database Features:
Procedures, Cursors, Triggers, Concurrency Prevention, and Views.
"""
import pymysql

def test_mysql_database_features():
    conn = pymysql.connect(host='127.0.0.1', port=3306, user='root', password='', db='swiftroute')
    with conn.cursor() as cur:
        # 1. Test sp_lookup_shipment_details
        cur.callproc('sp_lookup_shipment_details', ('SR-2026-1001',))
        manifest = cur.fetchone()
        assert manifest is not None, "Shipment lookup returned None"
        print(f"[+] sp_lookup_shipment_details SUCCESS: #{manifest[1]} [{manifest[2]}] - Customer: {manifest[12]}")
        cur.nextset()
        events = cur.fetchall()
        print(f"[+] Timeline events returned: {len(events)} events")
        assert len(events) >= 1, "Expected timeline events"

        # 2. Test sp_generate_operational_report
        cur.callproc('sp_generate_operational_report', ('2026-10-01', '2026-10-31'))
        report = cur.fetchone()
        assert report is not None
        print(f"[+] sp_generate_operational_report SUCCESS: Booked: {report[2]}, Delivered: {report[4]}, Total Billed: INR {report[7]}")

        # 3. Test trg_before_shipment_update (illegal transition from DELIVERED -> PENDING)
        blocked_transition = False
        try:
            cur.execute("UPDATE shipments SET status = 'PENDING' WHERE id = 'shp-1003';")
        except pymysql.MySQLError as e:
            blocked_transition = True
            print(f"[+] trg_before_shipment_update SUCCESS (Correctly blocked illegal status change): {e.args[1]}")
        assert blocked_transition, "Trigger failed to block status change on DELIVERED shipment"

        # 4. Test trg_prevent_busy_driver_assignment (concurrency check on busy driver)
        blocked_assignment = False
        try:
            # drv-002 is already booked on 2026-10-19 in asg-001
            cur.execute("INSERT INTO driver_assignments (id, driver_id, vehicle_id, route_id, assignment_date, status) VALUES ('asg-err', 'drv-002', 'veh-001', 'rt-001', '2026-10-19', 'SCHEDULED');")
        except pymysql.MySQLError as e:
            blocked_assignment = True
            print(f"[+] trg_prevent_busy_driver_assignment SUCCESS (Correctly blocked busy driver): {e.args[1]}")
        assert blocked_assignment, "Trigger failed to block concurrent driver assignment"

        # 5. Verify view vw_dashboard_kpis
        cur.execute("SELECT * FROM vw_dashboard_kpis;")
        kpis = cur.fetchone()
        print(f"[+] vw_dashboard_kpis SUCCESS: Total Shipments: {kpis[1]}, In-Transit: {kpis[2]}, Delivered: {kpis[3]}")

    conn.close()
    print("\n[+] ALL DATABASE CONSTRAINTS, TRIGGERS & PROCEDURES VERIFIED ON MYSQL 8.4 LTS!")

if __name__ == "__main__":
    test_mysql_database_features()
