input("a")
input("b")
output("q")

Nand("a")
wire("a", "a.a")
wire("b", "a.b")

Nand("b")
wire("a", "b.a")
wire("a.q", "b.b")

Nand("c")
wire("a.q", "c.a")
wire("b", "c.b")

Nand("d")
wire("b.q", "d.a")
wire("c.q", "d.b")

wire("d.q", "q")
