input("a")
input("b")
output("q")

Not("x")
Not("y")
Nand("z")

connect("a", "x.a")
connect("b", "y.a")
connect("x.q", "z.a")
connect("y.q", "z.b")
connect("z.q", "q")
