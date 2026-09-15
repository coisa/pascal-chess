# From the classroom to After Class

The owner identifies this as a university project. No course name, institution,
grade or original assignment date was supplied, so this documentation does not
invent them. The original is preserved by [release 0.1.0](https://github.com/coisa/pascal-chess/releases/tag/v0.1.0)
at commit `bec5c0cedae44637e2086ba9d6d52eb42a64b945`.

Source inspection found one 6,516-byte `chess.pas` file. It uses CRT to draw a
colored board and asks for source/destination coordinates. Its move procedure
copies the piece to the destination and clears the source. It does not check
legal movement, player turns, king safety, castling, promotion or en passant.
The main loop does not offer an exit command. Piece-count win messages exist
in a procedure that the main loop does not call.

That makes the starting point an exercise in Pascal data structures and
terminal drawing. The modernization adds the chess game itself, alongside a
native interface and a verifiable delivery process.

| Original | Modernized |
|---|---|
| One CRT program | Shared engine, Pascal search, SDL desktop and text CLI |
| Unrestricted piece copying | Legal moves, king safety and special moves |
| No turn/result enforcement | Turns, checkmate, stalemate and documented draw handling |
| Fixed terminal coordinates | Resizable graphical board and portable text commands |
| Portuguese identifiers and prompts | English source, UI and documentation |
| No tests or build recipe | Perft, rule/search tests, integration checks and pinned builds |

The experiment began with a simple request to see what today's AI could do
with a college project while keeping Pascal. The owner then expanded the
delivery to include issues, PRs, releases, Wiki automation and Dependabot.
The repository records the resulting implementation and evidence; it does not
claim an objective model ranking or pretend that validation and follow-up
instructions never happened. Git retains the evolution without parallel
legacy source copies.
