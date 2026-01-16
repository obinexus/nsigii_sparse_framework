#![no_main]
use libfuzzer_sys::fuzz_target;
use npl_parser::parse; // entry-point you want to hammer

fuzz_target!(|data: &[u8]| {
    if let Ok(s) = std::str::from_utf8(data) {
        let _ = parse(s); // should never panic / segfault
    }
});
