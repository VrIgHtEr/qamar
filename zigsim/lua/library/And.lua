input("a")
input("b")
output("q")

Nand("x")
Nand("y")

connect("a", "x.a")
connect("b", "x.b")
connect("x.q", "y.a")
connect("x.q", "y.b")
connect("y.q", "q")
