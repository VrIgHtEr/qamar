input("a")
input("b")
output("q")

Not("x")
connect("a", "x.a")

Not("y")
connect("b", "y.a")

Nand("z")
connect("x.q", "z.a")
connect("y.q", "z.b")

connect("z.q", "q")
