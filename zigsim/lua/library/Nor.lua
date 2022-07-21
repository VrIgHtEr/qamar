input("a")
input("b")
output("q")

Or("x")
connect("a", "x.a")
connect("b", "x.b")

Not("y")
connect("x.q", "y.a")
connect("y.q", "q")
