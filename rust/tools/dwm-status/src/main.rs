use chrono::Local;
use std::thread;
use std::time::Duration;
use xcb::{Connection, x};

fn main() {
    let (conn, screen_num) = Connection::connect(None).unwrap();
    let setup = conn.get_setup();
    let screen = setup.roots().nth(screen_num as usize).unwrap();
    let root_window = screen.root();

    loop {
        let current_time = Local::now().format("%Y-%m-%d %H:%M:%S").to_string();
        let status_text = current_time; // Placeholder for more complex status later

        println!("Setting status: {}", status_text); // For debugging

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
            property: wm_name_atom, // For DWM, this is often WM_NAME. Some WMs might use _NET_WM_NAME
            r#type: string_atom,    // Property type
            data: status_text.as_bytes(),
        });
        conn.flush().unwrap();

        thread::sleep(Duration::from_secs(1));
    }
}
