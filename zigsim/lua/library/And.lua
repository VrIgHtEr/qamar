input("a")
input("b")
output("q")

Nand("x")
connect("a", "x.a")
connect("b", "x.b")

Nand("y")
connect("x.q", "y.a")
connect("x.q", "y.b")

connect("y.q", "q")
