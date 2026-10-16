-- test_sync_engine.lua
local script_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./"
local repo_dir = script_dir .. "../"

package.path = repo_dir .. "kobostatsmerge.koplugin/?.lua;"
    .. "/Volumes/KOBOeReader/.adds/koreader/common/?.lua;"
    .. "/Volumes/KOBOeReader/.adds/koreader/?.lua;"
    .. package.path

local ffi = require("ffi")
if not ffi.loadlib then
    ffi.loadlib = function(name)
        return ffi.load(name)
    end
end

local SQ3 = require("lua-ljsqlite3/init")
local QVariant = require("qvariant")
local SyncEngine = require("sync_engine")

local BASE_DIR = os.getenv("TEST_DATA_DIR") or (repo_dir .. "tests/fixtures")
local TEST_DIR = repo_dir .. "tests/tmp_test_2way"
local BACKUP_DIR = TEST_DIR .. "/backups"

print("======================================================================")
print("TEST SUITE: KOBOSTATSMERGE 2-WAY SYNC ENGINE")
print("======================================================================")

-- Setup clean test environment
local function reset_test_env()
    os.execute("rm -rf " .. TEST_DIR)
    os.execute("mkdir -p " .. BACKUP_DIR)
    os.execute("cp " .. BASE_DIR .. "/backups/KoboReader.sqlite " .. TEST_DIR .. "/KoboReader.sqlite")
    os.execute("cp " .. BASE_DIR .. "/backups/statistics.sqlite3 " .. TEST_DIR .. "/statistics.sqlite3")
    os.execute("cp " .. BASE_DIR .. "/backups/bookinfo_cache.sqlite3 " .. TEST_DIR .. "/bookinfo_cache.sqlite3")
    os.execute("cp " .. BASE_DIR .. "/backups/docprops_cache.sqlite " .. TEST_DIR .. "/docprops_cache.sqlite")
end

reset_test_env()

local opts = {
    kobo_db_path = TEST_DIR .. "/KoboReader.sqlite",
    stats_db_path = TEST_DIR .. "/statistics.sqlite3",
    bookinfo_db_path = TEST_DIR .. "/bookinfo_cache.sqlite3",
    backup_dir = BACKUP_DIR,
    state_path = BACKUP_DIR .. "/kobo_stats_sync_state.lua",
    onboard_dir = "/Volumes/KOBOeReader",
}

-- Helper to verify all Kobo Event Checksums
local function verify_all_kobo_checksums(db_path)
    local conn = SQ3.open(db_path)
    local stmt = conn:prepare([[
        SELECT EventType, FirstOccurrence, LastOccurrence, EventCount, ContentID, hex(ExtraData), Checksum
        FROM Event;
    ]])
    local total = 0
    local matches = 0
    local failures = {}
    for row in stmt:rows() do
        total = total + 1
        local et = tonumber(row[1])
        local fo = row[2] and tostring(row[2]) or nil
        local lo = row[3] and tostring(row[3]) or nil
        local ec = tonumber(row[4]) or 0
        local cid = row[5] and tostring(row[5]) or ""
        local ed_hex = row[6] and tostring(row[6]) or ""
        local expected_ck = row[7] and tostring(row[7]) or ""
        local ed_raw = QVariant.hex_to_bytes(ed_hex)
        local computed_ck = QVariant.event_checksum(cid, ec, et, ed_raw, fo, lo)
        if computed_ck == expected_ck then
            matches = matches + 1
        else
            failures[#failures + 1] = { et = et, cid = cid, exp = expected_ck, got = computed_ck }
        end
    end
    stmt:close()
    conn:close()
    return total, matches, failures
end

-- Helper to get total reading time in KOReader
local function get_koreader_total_time(db_path)
    local conn = SQ3.open(db_path)
    local b_time, b_count = conn:rowexec("SELECT COALESCE(SUM(total_read_time), 0), COUNT(*) FROM book;")
    b_time = tonumber(b_time) or 0
    b_count = tonumber(b_count) or 0

    local psd_time, psd_count = conn:rowexec("SELECT COALESCE(SUM(duration), 0), COUNT(*) FROM page_stat_data;")
    psd_time = tonumber(psd_time) or 0
    psd_count = tonumber(psd_count) or 0
    conn:close()
    return b_time, b_count, psd_time, psd_count
end

-- Helper to get total reading time in Kobo
local function get_kobo_total_time(db_path)
    local conn = SQ3.open(db_path)
    local stmt = conn:prepare([[
        SELECT EventType, hex(ExtraData)
        FROM Event
        WHERE EventType IN (3, 46);
    ]])
    local sum_et46 = 0
    local sum_et3 = 0
    for row in stmt:rows() do
        local et = tonumber(row[1])
        local raw = QVariant.hex_to_bytes(tostring(row[2] or ""))
        local plain = QVariant.decode(raw)
        local sec = tonumber(plain.ExtraDataReadingSeconds) or 0
        if et == 46 then sum_et46 = sum_et46 + sec end
        if et == 3 then sum_et3 = sum_et3 + sec end
    end
    stmt:close()

    local sum_content = conn:rowexec("SELECT COALESCE(SUM(TimeSpentReading), 0) FROM content WHERE ContentType = '6';")
    sum_content = tonumber(sum_content) or 0
    conn:close()
    return sum_et46, sum_et3, sum_content
end

print("\n--- TEST 1: Initial 2-Way Sync (Run 1) ---")
local ok1, res1 = SyncEngine.run_two_way_sync(opts)
if not ok1 then
    print("TEST 1 FAILED:", res1)
    os.exit(1)
end
print("Run 1 Success!")
print(string.format("  Kobo -> KOReader: %d books, %d seconds", res1.kobo_to_ko_books, res1.kobo_to_ko_seconds))
print(string.format("  KOReader -> Kobo: %d books, %d seconds", res1.ko_to_kobo_books, res1.ko_to_kobo_seconds))

local ko_bt, ko_bc, ko_pt, ko_pc = get_koreader_total_time(opts.stats_db_path)
print(string.format("KOReader Stats: %d books, total_read_time = %d s, psd duration = %d s (count = %d)", ko_bc, ko_bt, ko_pt, ko_pc))

local kb_et46, kb_et3, kb_cnt = get_kobo_total_time(opts.kobo_db_path)
print(string.format("Kobo Stats: EventType 46 = %d s (%.2f h), EventType 3 = %d s, content sum = %d s", kb_et46, kb_et46/3600, kb_et3, kb_cnt))

local tot_ev, match_ev, fails = verify_all_kobo_checksums(opts.kobo_db_path)
print(string.format("Kobo Event Checksums: %d/%d valid matches (100%% = %s)", match_ev, tot_ev, tostring(tot_ev == match_ev)))
if #fails > 0 then
    print("FAILED CHECKSUMS DETECTED:")
    for _, f in ipairs(fails) do
        print(string.format("  ET %d CID %s: exp %s got %s", f.et, f.cid, f.exp, f.got))
    end
    os.exit(1)
end

local ok_int_s, err_int_s = SyncEngine.check_db_integrity(opts.stats_db_path, true)
local ok_int_k, err_int_k = SyncEngine.check_db_integrity(opts.kobo_db_path, true)
print(string.format("DB Integrity Check: KOReader = %s, Kobo = %s", tostring(ok_int_s), tostring(ok_int_k)))
assert(ok_int_s, "KOReader integrity check failed")
assert(ok_int_k, "Kobo integrity check failed")

print("\n--- TEST 2: Idempotency (Run 2) ---")
local ok2, res2 = SyncEngine.run_two_way_sync(opts)
if not ok2 then
    print("TEST 2 FAILED:", res2)
    os.exit(1)
end
print("Run 2 Success!")
print(string.format("  Kobo -> KOReader: %d books, %d seconds", res2.kobo_to_ko_books, res2.kobo_to_ko_seconds))
print(string.format("  KOReader -> Kobo: %d books, %d seconds", res2.ko_to_kobo_books, res2.ko_to_kobo_seconds))
assert(res2.kobo_to_ko_books == 0, "Expected 0 Kobo->KO books on second run")
assert(res2.kobo_to_ko_seconds == 0, "Expected 0 Kobo->KO seconds on second run")
assert(res2.ko_to_kobo_books == 0, "Expected 0 KO->Kobo books on second run")
assert(res2.ko_to_kobo_seconds == 0, "Expected 0 KO->Kobo seconds on second run")

local ko_bt2, ko_bc2, ko_pt2, ko_pc2 = get_koreader_total_time(opts.stats_db_path)
local kb_et46_2, kb_et3_2, kb_cnt_2 = get_kobo_total_time(opts.kobo_db_path)
assert(ko_bt2 == ko_bt, "KOReader total_read_time changed during idempotent run")
assert(kb_et46_2 == kb_et46, "Kobo EventType 46 changed during idempotent run")
print("Idempotency verified: 0 spurious deltas added!")

print("\n--- TEST 3: Incremental KOReader Reading Simulation ---")
-- Simulate user reading 1800s (30m) on Book ID 1 in KOReader
local conn_ko = SQ3.open(opts.stats_db_path)
local sim_start_time = os.time() + 1000
conn_ko:exec(string.format([[
    INSERT INTO page_stat_data (id_book, page, start_time, duration, total_pages)
    VALUES (1, 50, %d, 1800, 300);
    UPDATE book
    SET total_read_time = total_read_time + 1800,
        total_read_pages = total_read_pages + 1,
        last_open = %d
    WHERE id = 1;
]], sim_start_time, sim_start_time + 1800))
conn_ko:close()

local ok3, res3 = SyncEngine.run_two_way_sync(opts)
if not ok3 then
    print("TEST 3 FAILED:", res3)
    os.exit(1)
end
print("Run 3 (KOReader Reading Delta) Success!")
print(string.format("  KOReader -> Kobo: %d books, %d seconds", res3.ko_to_kobo_books, res3.ko_to_kobo_seconds))
assert(res3.ko_to_kobo_books >= 1, "Expected at least 1 book updated in Kobo")
assert(res3.ko_to_kobo_seconds >= 1800, "Expected at least 1800 seconds propagated to Kobo")

local kb_et46_3, _, kb_cnt_3 = get_kobo_total_time(opts.kobo_db_path)
print(string.format("Kobo EventType 46 after KO read: %d s (delta = +%d s)", kb_et46_3, kb_et46_3 - kb_et46_2))
assert(kb_et46_3 == kb_et46_2 + 1800, "Kobo EventType 46 did not increase by exactly 1800s")

local tot_ev3, match_ev3, _ = verify_all_kobo_checksums(opts.kobo_db_path)
assert(tot_ev3 == match_ev3, "Checksums invalid after incremental sync")
print("Incremental KOReader reading delta propagated accurately to Kobo with valid checksums!")

print("\n--- TEST 4: Incremental Kobo Reading Simulation ---")
-- Simulate user reading in Kobo stock app for 1200s (20m) on book 1's ContentID
local conn_kobo = SQ3.open(opts.kobo_db_path)
local test_cid = conn_kobo:rowexec("SELECT ContentID FROM content WHERE ContentType = '6' AND TimeSpentReading > 0 LIMIT 1;")

local hex_ed, ev_count, first_occ, last_occ = conn_kobo:rowexec(string.format([[
    SELECT hex(ExtraData), EventCount, FirstOccurrence, LastOccurrence
    FROM Event WHERE ContentID = '%s' AND EventType = 46;
]], test_cid))
local raw_ed = QVariant.hex_to_bytes(hex_ed)
local plain_ed, ast_ed = QVariant.decode(raw_ed)
local old_sec = tonumber(plain_ed.ExtraDataReadingSeconds) or 0
local new_sec = old_sec + 1200
ast_ed.ExtraDataReadingSeconds = QVariant.qint(new_sec)
ast_ed.ExtraDataReadingSessions = QVariant.qint((tonumber(plain_ed.ExtraDataReadingSessions) or 1) + 1)
local new_lo = os.date("!%Y-%m-%dT%H:%M:%S.000", os.time() + 5000)
local new_ed_bytes = QVariant.encode_ast(ast_ed)
local new_ed_hex = QVariant.bytes_to_hex(new_ed_bytes)
local new_ck = QVariant.event_checksum(test_cid, tonumber(ev_count), 46, new_ed_bytes, first_occ, new_lo)

conn_kobo:exec(string.format([[
    UPDATE content
    SET TimeSpentReading = TimeSpentReading + 1200,
        DateLastRead = '%s'
    WHERE ContentID = '%s';
    UPDATE Event
    SET ExtraData = X'%s',
        LastOccurrence = '%s',
        Checksum = '%s'
    WHERE ContentID = '%s' AND EventType = 46;
]], new_lo, test_cid, new_ed_hex, new_lo, new_ck, test_cid))
conn_kobo:close()

local ok4, res4 = SyncEngine.run_two_way_sync(opts)
if not ok4 then
    print("TEST 4 FAILED:", res4)
    os.exit(1)
end
print("Run 4 (Kobo Reading Delta) Success!")
print(string.format("  Kobo -> KOReader: %d books, %d seconds", res4.kobo_to_ko_books, res4.kobo_to_ko_seconds))
assert(res4.kobo_to_ko_books >= 1, "Expected at least 1 book updated in KOReader")
assert(res4.kobo_to_ko_seconds == 1200, "Expected exactly 1200 seconds propagated to KOReader")

local ko_bt4, _, ko_pt4, _ = get_koreader_total_time(opts.stats_db_path)
print(string.format("KOReader total_read_time after Kobo read: %d s (delta = +%d s)", ko_bt4, ko_bt4 - ko_bt2 - 1800))
assert(ko_bt4 == ko_bt2 + 1800 + 1200, "KOReader total_read_time did not reflect Kobo delta")
print("Incremental Kobo reading delta propagated accurately to KOReader!")

print("\n--- TEST 5: Backup Files Verification ---")
local golden_ko = io.open(BACKUP_DIR .. "/statistics.sqlite3.golden.bak", "rb")
local golden_kb = io.open(BACKUP_DIR .. "/KoboReader.sqlite.golden.bak", "rb")
local bak1_ko = io.open(BACKUP_DIR .. "/statistics.sqlite3.bak.1", "rb")
local bak1_kb = io.open(BACKUP_DIR .. "/KoboReader.sqlite.bak.1", "rb")
assert(golden_ko and golden_kb and bak1_ko and bak1_kb, "Expected backup files not found!")
golden_ko:close()
golden_kb:close()
bak1_ko:close()
bak1_kb:close()
print("Backup files (.golden.bak, .bak.1) verified successfully!")

print("\n======================================================================")
print("ALL TESTS PASSED! 2-Way Sync Engine is Rock Solid!")
print("======================================================================")
