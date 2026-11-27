extends Resource
class_name BattleTextRules
## Настраиваемые фразы для существующего BattleText в FightScene.
## Слова в фигурных скобках — параметры, заменяемые при показе сообщения.
## Сохраняй имена параметров, меняй только окружающий текст.

@export_group("Атака")
@export_multiline var attack: String = "{hero} атакует!"
@export_multiline var counterattack: String = "{hero} контратакует!"
@export_multiline var extra_attack: String = "{hero} атакует повторно!"
@export_multiline var dodge: String = "{target} уклоняется!"
@export_multiline var damage: String = "{target} получает {damage} ед. урона."
@export_multiline var critical_damage: String = "Критический удар! {target} получает {damage} ед. урона."
@export_multiline var defeated: String = "{target} повержен!"

@export_group("Лечение и предметы")
@export_multiline var item_use: String = "{hero} применяет {item}!"
@export_multiline var heal: String = "{target} восстановлено {heal} HP."
@export_multiline var heal_xp: String = "{hero} получает {xp} XP."

@export_group("Магия")
@export_multiline var spell_cast: String = "{hero} применяет {spell}!"
@export_multiline var magic_dodge: String = "{target} избегает магии!"
@export_multiline var magic_damage: String = "{target} получает {damage} ед. урона."
@export_multiline var magic_xp: String = "{hero} получает {xp} XP."

@export_group("Опыт за боевые действия")
@export_multiline var action_xp: String = "{hero} получает {xp} XP."

@export_group("Награды")
@export_multiline var gold_received: String = "{hero} получает {gold} золота!"
@export_multiline var item_found: String = "{hero} находит {item} x{count}!"

@export_group("Будущее: уровни и характеристики")
@export_multiline var level_up: String = "{hero} достигает уровня {level}!"
@export_multiline var stat_increase: String = "{hero}: {stat} +{amount}!"
@export_multiline var max_hp_increase: String = "Максимальное HP {hero} увеличено на {amount}!"
@export_multiline var max_mp_increase: String = "Максимальное MP {hero} увеличено на {amount}!"

