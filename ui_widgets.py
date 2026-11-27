import webbrowser
import tkinter as tk
from config import THEME


def render_news_cards(container, articles):
    for widget in container.winfo_children():
        widget.destroy()

    for date_str, title, excerpt, link in articles:
        card = tk.Frame(
            container,
            bg=THEME["bg_card"],
            highlightbackground=THEME["border"],
            highlightthickness=1,
        )
        card.pack(fill="x", padx=6, pady=4)

        top_row = tk.Frame(card, bg=THEME["bg_card"])
        top_row.pack(fill="x", padx=8, pady=(6, 2))

        lbl_title = tk.Label(
            top_row,
            text=title,
            font=("Segoe UI", 10, "bold"),
            fg=THEME["text_title"],
            bg=THEME["bg_card"],
            cursor="hand2",
            anchor="w",
        )
        lbl_title.pack(side="left", fill="x", expand=True)
        lbl_title.bind("<Button-1>", lambda e, u=link: webbrowser.open(u))

        if date_str:
            tk.Label(
                top_row,
                text=date_str,
                font=("Segoe UI", 8),
                fg=THEME["text_muted"],
                bg=THEME["bg_card"],
            ).pack(side="right")

        if excerpt:
            short_text = (excerpt[:190] + "...") if len(excerpt) > 190 else excerpt
            tk.Label(
                card,
                text=short_text,
                font=("Segoe UI", 9),
                fg=THEME["text_main"],
                bg=THEME["bg_card"],
                justify="left",
                wraplength=510,
                anchor="w",
            ).pack(fill="x", padx=8, pady=(0, 6))
