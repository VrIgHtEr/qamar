input("a")
input("b")
output("q")

Or("x")
connect("a", "x.a")
connect("b", "x.b")

Nand("y")
connect("a", "y.a")
connect("b", "y.b")

Nand("z")
connect("x.q", "z.a")
connect("y.q", "z.b")

connect("z.q", "q")
