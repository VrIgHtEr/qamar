return function()
	input("a")
	input("b")
	output("c")
	Nand("X")
	Nand("Y")
	connect("a", "X.a")
	connect("b", "X.b")
	connect("X.c", "Y.a")
	connect("X.c", "Y.b")
	connect("Y.c", "c")
end
