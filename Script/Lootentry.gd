class_name LootEntry
extends Resource
## One line of a LootTable: which item, how likely, how many.

@export var item: ItemDef
@export var weight := 1.0          # relative chance: weight 3 comes up three times as often as weight 1
@export var min_count := 1
@export var max_count := 1
