extends Node

# Autoload

const charactersById = {
	1: {
		"name": "Peter",
		"scene": preload("res://player.tscn"),
		"id": 1,
	},
	2: {
		"name": "Guncar",
		"scene": preload("res://guncar.tscn"),
		"id": 2,
	}
}

const mapsById = {
	1: {
		"name": "Streets",
		"scene": preload("res://skreets.tscn"),
		"id": 1,
	},
	2: {
		"name": "Dalaran",
		"scene": preload("res://dalaran.tscn"),
		"id": 2,
	}
}
