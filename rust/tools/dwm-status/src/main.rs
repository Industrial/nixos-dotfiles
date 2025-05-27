mod metrics;
use std::thread;
use std::time::Duration;
use xcb::{Connection, x};

use crate::metrics::datetime::get_date_time;

fn main() {
    let (conn, screen_num) = Connection::connect(None).unwrap();
    let setup = conn.get_setup();
    let screen = setup.roots().nth(screen_num as usize).unwrap();
    let root_window = screen.root();

    loop {
        let datetime_text = get_date_time();
        let status_text = format!("{}", datetime_text);

        println!("Setting status: {}", status_text);

        let wm_name_atom_cookie = conn.send_request(&x::InternAtom {
            only_if_exists: false,
            name: b"WM_NAME",
        });
        let string_atom_cookie = conn.send_request(&x::InternAtom {
            only_if_exists: false,
            name: b"STRING",
        });

        let wm_name_atom = conn.wait_for_reply(wm_name_atom_cookie).unwrap().atom();
        let string_atom = conn.wait_for_reply(string_atom_cookie).unwrap().atom();

        conn.send_request_checked(&x::ChangeProperty {
            mode: x::PropMode::Replace,
            window: root_window,
            property: wm_name_atom,
            r#type: string_atom,
            data: status_text.as_bytes(),
        });
        conn.flush().unwrap();

        thread::sleep(Duration::from_secs(1));
    }
}
