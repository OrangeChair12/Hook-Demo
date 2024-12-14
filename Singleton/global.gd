extends Node2D

signal health_updated(hp)
signal hook_range_updated(new_range)

var player: Player = null
var selected_hook: HookablePointBase = null
