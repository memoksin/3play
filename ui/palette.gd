class_name Palette
## Resurrect 64 (Lospec). Named roles for UI; ALL holds the full palette in order.

const BG := Color("2e222f")          # screen background
const PANEL := Color("3e3546")       # cards, buttons
const PANEL_DARK := Color("45293f")  # pressed, shadows
const BORDER := Color("625565")      # 1 logical px outlines
const MUTED := Color("9babb2")       # secondary text, disabled
const TEXT := Color("c7dcd0")        # body text
const WHITE := Color("ffffff")       # highlights, hover text

const DANGER := Color("ea4f36")      # timer < 10 s, fail
const WARN := Color("fb6b1d")        # timer < 30 s
const GOLD := Color("f9c22b")        # focus, real-event numbers
const SAFE := Color("1ebc73")        # saved people, success

const STATE := Color("0eaf9b")       # State role accent
const CITIZEN := Color("f79617")     # Citizen role accent
const GLITCH_A := Color("e83b3b")    # logo / 4D glitch split, left
const GLITCH_B := Color("4d9be6")    # logo / 4D glitch split, right

const ALL: Array[String] = [
	"2e222f", "3e3546", "625565", "966c6c", "ab947a", "694f62", "7f708a", "9babb2",
	"c7dcd0", "ffffff", "6e2727", "b33831", "ea4f36", "f57d4a", "ae2334", "e83b3b",
	"fb6b1d", "f79617", "f9c22b", "7a3045", "9e4539", "cd683d", "e6904e", "fbb954",
	"4c3e24", "676633", "a2a947", "d5e04b", "fbff86", "165a4c", "239063", "1ebc73",
	"91db69", "cddf6c", "313638", "374e4a", "547e64", "92a984", "b2ba90", "0b5e65",
	"0b8a8f", "0eaf9b", "30e1b9", "8ff8e2", "323353", "484a77", "4d65b4", "4d9be6",
	"8fd3ff", "45293f", "6b3e75", "905ea9", "a884f3", "eaaded", "753c54", "a24b6f",
	"cf657f", "ed8099", "831c5d", "c32454", "f04f78", "f68181", "fca790", "fdcbb0",
]
