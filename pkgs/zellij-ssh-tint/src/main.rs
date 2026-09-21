//! zellij-ssh-tint — tint a pane red while it runs an ssh session.
//!
//! Zellij reports every pane's running command to subscribed plugins, so a
//! plugin can passively detect "this pane is *ssh host*" with no shell wrapper
//! and no changes on the remote host. This colors such panes (configurable,
//! default `#3a0000`) so you can tell at a glance that you're on a remote box.
//!
//! Detection uses `Event::CommandChanged`, which zellij fires with the
//! foreground process argv (e.g. `["ssh", "host"]`) the moment a command
//! launches. It is *not* `PaneUpdate + PaneInfo.title`: zellij sets the pane
//! title via an OSC window-title escape and deliberately does **not** emit a
//! `PaneUpdate` for such title changes (zellij-org/zellij#5482), so title-based
//! detection silently never fires even though the grant is approved. The
//! `PaneUpdate` handler below only does bookkeeping (drop closed panes, don't
//! clobber a pane the user tinted themselves).
//!
//! Permission: on first ever load zellij prompts once to Approve
//! `ReadApplicationState` + `ChangeApplicationState`; afterwards the grant is
//! cached and auto-applied (same flow as zjstatus/tab-rename).
use std::collections::{BTreeMap, HashSet};

use zellij_tile::prelude::*;

const DEFAULT_BG: &str = "#3a0000";

#[derive(Default)]
struct SshTint {
    color: String,
    tinted: HashSet<u32>,
    permissions_granted: bool,
}

register_plugin!(SshTint);

impl ZellijPlugin for SshTint {
    // color comes from the load_plugins block, e.g.  color "#7a1000"
    fn load(&mut self, configuration: BTreeMap<String, String>) {
        self.color = configuration
            .get("color")
            .cloned()
            .unwrap_or_else(|| DEFAULT_BG.to_string());
        request_permission(&[
            PermissionType::ReadApplicationState,
            PermissionType::ChangeApplicationState,
        ]);
        subscribe(&[
            EventType::PermissionRequestResult,
            EventType::CommandChanged,
            EventType::PaneUpdate,
        ]);
    }

    fn update(&mut self, event: Event) -> bool {
        match event {
            Event::PermissionRequestResult(PermissionStatus::Granted) => {
                self.permissions_granted = true;
            }
            Event::PermissionRequestResult(_) => {}
            // reliable trigger: zellij sends the foreground process argv (e.g.
            // `["ssh", "host"]`) the instant a command goes foreground.
            Event::CommandChanged(pane_id, command, _is_foreground, _client_ids) => {
                if self.permissions_granted {
                    self.apply_for_command(pane_id, &command);
                }
            }
            // bookkeeping only (tint detection lives in CommandChanged): drop
            // ids of panes that closed so `tinted` doesn't grow unbounded.
            // ponytail: no default_bg / "user colored" guard here — set_pane_color
            // on a terminal pane makes the manifest report default_bg as our own
            // tint, so any default_bg-based heuristic mistakes our tint for a
            // manual one and immediately un-tints it (the red flash then revert).
            Event::PaneUpdate(manifest) => {
                if self.permissions_granted {
                    self.sync_from_manifest(manifest);
                }
            }
            _ => {}
        }
        false
    }
}

impl SshTint {
    fn apply_for_command(&mut self, pane_id: PaneId, argv: &[String]) {
        let PaneId::Terminal(id) = pane_id else {
            return;
        };
        if is_ssh(argv) {
            if !self.tinted.contains(&id) {
                set_pane_color(PaneId::Terminal(id), None, Some(self.color.clone()));
                self.tinted.insert(id);
            }
        } else if self.tinted.remove(&id) {
            // foreground is the shell / a non-ssh command again — untint
            set_pane_color(PaneId::Terminal(id), None, None);
        }
    }

    fn sync_from_manifest(&mut self, manifest: PaneManifest) {
        let alive: HashSet<u32> = manifest
            .panes
            .values()
            .flatten()
            .filter(|p| !p.is_plugin)
            .map(|p| p.id)
            .collect();
        // drop ids of panes that have closed
        self.tinted.retain(|id| alive.contains(id));
    }
}

/// Is `argv` an `ssh` invocation? First arg (ignoring a leading path) == `ssh`.
/// Catches `ssh host`, `ssh -p 2222 host`, `/usr/bin/ssh host`.
fn is_ssh(argv: &[String]) -> bool {
    argv.first()
        .map(|first| first.rsplit('/').next().unwrap_or(first) == "ssh")
        .unwrap_or(false)
}
