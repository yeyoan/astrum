extends Node

const BLUE = Color("#07f9dc")
const PINK = Color("#fa1f79")
const ORANGE = Color("#f7a757")

const COLORS: Array = [PINK, ORANGE]

var current = BLUE


func randomize() -> Color:
    var tmp = COLORS.pop_back()
    COLORS.push_front(current)
    current = tmp
    return current