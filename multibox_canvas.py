"""Componente visual interactivo (Canvas) para organizar monitores y ventanas WoW."""
import tkinter as tk
from config import THEME
from multibox_layouts import PRESAVED_LAYOUTS, compute_monitor_subrects


class MultiboxPreviewCanvas(tk.Frame):
    def __init__(self, parent, state_callbacks):
        super().__init__(parent, bg=THEME["bg_bar"], highlightbackground=THEME["border"], highlightthickness=1)
        self.cb = state_callbacks
        self.sel_idx = -1
        self.rect_boxes = []
        self.mon_boxes = []
        self.empty_zones = []
        self.drag_state = {"slot": -1, "x": 0, "y": 0, "dragging": False}

        self.title_lbl = tk.Label(
            self,
            text="VISTA PREVIA — MAXIMO 24 WOWS",
            font=("Segoe UI", 8, "bold"),
            fg=THEME["text_muted"],
            bg=THEME["bg_bar"],
        )
        self.title_lbl.pack(pady=(5, 2))

        self.canvas = tk.Canvas(self, height=205, bg="#040e18", highlightthickness=0)
        self.canvas.pack(fill="both", expand=True, padx=12, pady=(2, 8))

        self.canvas.bind("<Configure>", self.draw)
        self.canvas.bind("<ButtonPress-1>", self._on_press)
        self.canvas.bind("<B1-Motion>", self._on_drag)
        self.canvas.bind("<ButtonRelease-1>", self._on_release)
        self.canvas.bind("<Button-3>", self._on_right_click)

    def clear_selection(self):
        self.sel_idx = -1

    def _on_press(self, event):
        clicked = -1
        for idx, (x1, y1, x2, y2) in enumerate(self.rect_boxes):
            if x1 <= event.x <= x2 and y1 <= event.y <= y2:
                clicked = idx
                break
        self.drag_state = {"slot": clicked, "x": event.x, "y": event.y, "dragging": False}

    def _on_drag(self, event):
        s_idx = self.drag_state["slot"]
        if s_idx == -1:
            return
        if abs(event.x - self.drag_state["x"]) > 5 or abs(event.y - self.drag_state["y"]) > 5:
            self.drag_state["dragging"] = True
        if self.drag_state["dragging"]:
            self.canvas.delete("drag_ghost")
            acc_lbl, _ = self.cb["get_slot_info"](s_idx)
            self.canvas.create_rectangle(
                event.x - 55, event.y - 20, event.x + 55, event.y + 20,
                fill="#1b4f72", outline="#ffd54f", width=2, tags="drag_ghost",
            )
            self.canvas.create_text(
                event.x, event.y, text=f"#{s_idx + 1} {acc_lbl}",
                fill="#ffffff", font=("Segoe UI", 8, "bold"), tags="drag_ghost",
            )

    def _on_release(self, event):
        self.canvas.delete("drag_ghost")
        src_idx = self.drag_state["slot"]
        was_dragging = self.drag_state["dragging"]
        self.drag_state = {"slot": -1, "x": 0, "y": 0, "dragging": False}
        if src_idx == -1:
            return

        if was_dragging:
            for (ex1, ey1, ex2, ey2, m_idx, z_idx) in self.empty_zones:
                if ex1 <= event.x <= ex2 and ey1 <= event.y <= ey2:
                    self.cb["drop_on_empty_zone"](src_idx, m_idx, z_idx)
                    return

            target_slot = -1
            for idx, (x1, y1, x2, y2) in enumerate(self.rect_boxes):
                if x1 <= event.x <= x2 and y1 <= event.y <= y2:
                    target_slot = idx
                    break
            if target_slot != -1 and target_slot != src_idx:
                self.cb["swap_slots"](src_idx, target_slot)
                return

            for m_idx, (mx1, my1, mx2, my2) in enumerate(self.mon_boxes):
                if mx1 <= event.x <= mx2 and my1 <= event.y <= my2:
                    self.cb["drop_on_monitor"](src_idx, m_idx)
                    return
        else:
            if self.sel_idx == -1:
                self.sel_idx = src_idx
                self.draw()
            elif self.sel_idx == src_idx:
                self.sel_idx = -1
                self.draw()
            else:
                self.cb["swap_slots"](self.sel_idx, src_idx)

    def _on_right_click(self, event):
        target_mon = -1
        for m_idx, (mx1, my1, mx2, my2) in enumerate(self.mon_boxes):
            if mx1 <= event.x <= mx2 and my1 <= event.y <= my2:
                target_mon = m_idx
                break
        if target_mon == -1:
            return
        menu = tk.Menu(
            self, tearoff=0, bg=THEME["bg_card"], fg=THEME["text_main"],
            activebackground=THEME["accent"], activeforeground="#04121f",
            font=("Segoe UI", 9, "bold"),
        )
        menu.add_command(label=f"Monitor {target_mon + 1}: Dividir horizontal (50% | 50%)", command=lambda m=target_mon: self.cb["split_monitor"](m, "h_split"))
        menu.add_command(label=f"Monitor {target_mon + 1}: Dividir vertical (50% / 50%)", command=lambda m=target_mon: self.cb["split_monitor"](m, "v_split"))
        menu.add_separator()
        menu.add_command(label=f"Monitor {target_mon + 1}: Prioridad horizontal (2/3 | 1/3)", command=lambda m=target_mon: self.cb["split_monitor"](m, "h_prio"))
        menu.add_command(label=f"Monitor {target_mon + 1}: Prioridad vertical (2/3 / 1/3)", command=lambda m=target_mon: self.cb["split_monitor"](m, "v_prio"))
        menu.add_separator()
        menu.add_command(label=f"Monitor {target_mon + 1}: Quitar división (Automático)", command=lambda m=target_mon: self.cb["split_monitor"](m, "auto"))
        menu.tk_popup(event.x_root, event.y_root)
    def draw(self, _event=None):
        self.canvas.delete("all")
        self.rect_boxes.clear()
        self.mon_boxes.clear()
        self.empty_zones.clear()

        cw = max(self.canvas.winfo_width(), 300)
        ch = max(self.canvas.winfo_height(), 140)
        rects = self.cb["get_active_rects"]()
        arranged = self.cb["get_arranged_monitors"]()
        split_modes, slot_zones = self.cb["get_split_state"]()
        show_borders, layout_name, cols_cnt = self.cb["get_visual_flags"]()

        all_boxes = [r for _, r in arranged] if len(arranged) > 1 else [self.cb["get_current_area"]()]
        all_boxes.extend(rects)
        min_x = min(bx for bx, by, bw, bh in all_boxes)
        min_y = min(by for bx, by, bw, bh in all_boxes)
        max_x = max(bx + bw for bx, by, bw, bh in all_boxes)
        max_y = max(by + bh for bx, by, bw, bh in all_boxes)
        span_w = max(1, max_x - min_x)
        span_h = max(1, max_y - min_y)

        self.title_lbl.config(text=f"VISTA PREVIA ({span_w}x{span_h} px) — Clic derecho en un monitor para dividirlo | Arrastra WoWs a los huecos")

        pad = 8
        avail_w, avail_h = cw - pad * 2, ch - pad * 2
        scale = min(avail_w / span_w, avail_h / span_h)
        inner_w = int(span_w * scale)
        inner_h = int(span_h * scale)
        off_x = pad + (avail_w - inner_w) // 2
        off_y = pad + (avail_h - inner_h) // 2

        for m_idx, (mlbl, (mx, my, mw, mh)) in enumerate(arranged):
            mx1 = off_x + int(((mx - min_x) / span_w) * inner_w)
            my1 = off_y + int(((my - min_y) / span_h) * inner_h)
            mx2 = off_x + int(((mx - min_x + mw) / span_w) * inner_w)
            my2 = off_y + int(((my - min_y + mh) / span_h) * inner_h)
            self.mon_boxes.append((mx1, my1, mx2, my2))
            self.canvas.create_rectangle(mx1, my1, mx2, my2, outline="#2b5b84", dash=(4, 3), width=1)
            short_m = next(iter(mlbl.split(" — ")))
            self.canvas.create_text(mx1 + 6, my1 + 4, text=short_m, fill="#5c9bc9", font=("Segoe UI", 7, "bold"), anchor="nw")

            mode = split_modes.get(m_idx, "auto")
            zones = slot_zones.get(m_idx, [])
            if mode != "auto" and zones:
                sub_rects = compute_monitor_subrects(mode, len(zones), mx, my, mw, mh, cols_cnt)
                for z_i, s_val in enumerate(zones):
                    if s_val is None and z_i < len(sub_rects):
                        zx, zy, zw, zh = sub_rects[z_i]
                        ex1 = off_x + int(((zx - min_x) / span_w) * inner_w) + 3
                        ey1 = off_y + int(((zy - min_y) / span_h) * inner_h) + 3
                        ex2 = off_x + int(((zx - min_x + zw) / span_w) * inner_w) - 3
                        ey2 = off_y + int(((zy - min_y + zh) / span_h) * inner_h) - 3
                        self.empty_zones.append((ex1, ey1, ex2, ey2, m_idx, z_i))
                        self.canvas.create_rectangle(ex1, ey1, ex2, ey2, fill="#081c30", outline="#4fc3f7", dash=(5, 4), width=1)
                        self.canvas.create_text((ex1 + ex2) // 2, (ey1 + ey2) // 2, text=f"+ Hueco libre\n({zw}x{zh})\nArrastra un WoW aquí", fill="#4fc3f7", font=("Segoe UI", 8, "bold"), justify="center")

        for idx, (rx, ry, rw, rh) in enumerate(rects):
            x1 = off_x + int(((rx - min_x) / span_w) * inner_w) + 2
            y1 = off_y + int(((ry - min_y) / span_h) * inner_h) + 2
            x2 = off_x + int(((rx - min_x + rw) / span_w) * inner_w) - 2
            y2 = off_y + int(((ry - min_y + rh) / span_h) * inner_h) - 2
            self.rect_boxes.append((x1, y1, x2, y2))

            acc_name, cli_name = self.cb["get_slot_info"](idx)
            is_sel = (idx == self.sel_idx)
            is_primary = (idx == 0 and layout_name != next(iter(PRESAVED_LAYOUTS)))
            fill_col = "#1b4f72" if is_sel else ("#0e3152" if is_primary else THEME["bg_card"])
            out_col = "#ffd54f" if is_sel else THEME["border_bright"]
            self.canvas.create_rectangle(x1, y1, x2, y2, fill=fill_col, outline=out_col, width=2 if is_sel else 1)

            if show_borders:
                bar_h = min(16, max(8, (y2 - y1) // 5))
                self.canvas.create_rectangle(x1, y1, x2, y1 + bar_h, fill="#ffd54f" if is_sel else THEME["accent"], outline="")
                self.canvas.create_text((x1 + x2) // 2, y1 + bar_h // 2, text=f"#{idx + 1} ({rw}x{rh})", fill="#04121f", font=("Segoe UI", 7, "bold"))
                body_y = (y1 + y2 + bar_h) // 2
            else:
                body_y = (y1 + y2) // 2

            box_w, box_h = x2 - x1, y2 - y1
            if box_w < 110 or box_h < 42:
                lbl = f"#{idx + 1} {acc_name}"
                fsize = 7
            else:
                lbl = f"#{idx + 1} {acc_name}\n[{cli_name}] ({rw}x{rh})"
                fsize = max(8, min(11, box_w // 20))
            self.canvas.create_text((x1 + x2) // 2, body_y, text=lbl, fill=THEME["text_main"], font=("Segoe UI", fsize, "bold"), justify="center")