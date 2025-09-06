from rich.console import Console
from rich.panel import Panel
import sys
def main():
    c = Console()
    if len(sys.argv)>1 and sys.argv[1] in ('-h','--help'):
        c.print("AI Terminal - help", style="cyan"); return
    c.print(Panel.fit("[bold]AI Terminal[/] — type ':quit' to exit", style="green"))
    try:
        while True:
            line = c.input("[bold cyan]ai-term[/]$ ").strip()
            if line in (":quit","quit","exit"): c.print("Bye 👋", style="cyan"); break
            if line.lower().startswith("ai:"):
                c.print(Panel.fit(f"Interpreted as (demo): {line[3:].strip()}", title="NL → Command", style="blue"))
            else:
                c.print(f"(demo) You typed: {line}", style="dim")
    except (EOFError, KeyboardInterrupt):
        c.print("\nBye 👋", style="cyan")
