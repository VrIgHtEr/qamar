input("a")
input("b")
output("q")

Not("x")
wire("a", "x.a")

Not("y")
wire("b", "y.a")

Nand("z")
wire("x.q", "z.a")
wire("y.q", "z.b")

wire("z.q", "q")
