input("a")
input("b")
output("q")

Nand("a")
connect("a", "a.a")
connect("b", "a.b")

Nand("b")
connect("a", "b.a")
connect("a.q", "b.b")

Nand("c")
connect("a.q", "c.a")
connect("b", "c.b")

Nand("d")
connect("b.q", "d.a")
connect("c.q", "d.b")

connect("d.q", "q")
