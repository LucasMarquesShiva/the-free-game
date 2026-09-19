extends RefCounted
## Read-only snapshot of waits already reported by the simulation.

static func collect(sim: RefCounted) -> Array[Dictionary]:
	var groups: Dictionary = {}
	var waits: Array[String] = []
	for message in ["Aguardando retirada da produção", "Aguardando equipamento no quartel", "Sem árvores acessíveis para cortar", "Pedreira sem jazida", "Estrada interrompida: carga preservada", "Aguardando estrada conectada", "Carga preservada: reconecte a estrada ao depósito", "Aguardando reconexão da estrada", "Estrada interrompida: aguardando reconexão", "Pedra preservada: reconecte o traçado ao depósito", "Aguardando reconexão do traçado", "Depósito cheio: pedra preservada"]:
		waits.append(TranslationServer.translate(message))
	for item in sim.ITEM_NAMES.values():
		waits.append(TranslationServer.translate("Aguardando {item}").format({"item":TranslationServer.translate(item)}))
	var buildings: Array = sim.get("buildings")
	var workers: Array = sim.get("workers")
	var covered_workers: Dictionary = {}
	for building: Dictionary in buildings:
		var stage: String = building.get("stage", "")
		if stage == "cancelled":
			continue
		var reason: String = building.get("reason", "")
		var blocked := false
		if building.kind != "hall" and not sim.is_building_connected(building):
			reason = TranslationServer.translate("Conecte a entrada à estrada do edifício principal")
			blocked = true
		elif stage != "complete":
			blocked = int(building.get("builder", -1)) < 0
		else:
			var role: String = sim.definition(building.kind).get("profession", "")
			blocked = not role.is_empty() and int(building.get("worker", -1)) < 0
			if blocked:
				reason = TranslationServer.translate("Forme um {role}").format({"role":TranslationServer.translate(sim.ROLE_NAMES.get(role, role)).to_lower()})
			elif building.kind == "farm":
				var crop: Dictionary = sim.crop_status(building)
				blocked = not crop.get("active", true) and crop.get("reason", "") not in ["", TranslationServer.translate("Jogo pausado"), TranslationServer.translate("Cultivo interrompido"), TranslationServer.translate("Horticultor a caminho da horta")]
				if blocked: reason = crop.reason
			if not blocked and reason in waits:
				blocked = true
		if blocked and not reason.is_empty():
			_add(groups, reason, str(sim.definition(building.kind).get("name", building.kind)), building.cell)
			covered_workers[int(building.get("worker", -1))] = true
	for worker: Dictionary in workers:
		var reason: String = worker.get("state", "")
		if not covered_workers.has(int(worker.id)) and reason in waits:
			_add(groups, reason, TranslationServer.translate(sim.ROLE_NAMES.get(worker.role, worker.role)), worker.cell)
	for road: Dictionary in sim.get("roads"):
		if road.stage in ["planned", "building"] and int(road.get("builder", -1)) < 0 and int(road.get("carrier", -1)) < 0:
			_add(groups, road.get("reason", ""), TranslationServer.translate("Estradas"), road.cell)
	for course: Dictionary in sim.get("training"):
		var role := str(TranslationServer.translate(sim.ROLE_NAMES.get(course.role, course.role)))
		var reason: String = course.get("reason", "")
		if reason.is_empty() or reason == TranslationServer.translate("Formando {role}").format({"role":role.to_lower()}) or reason == TranslationServer.translate("Morador indo ao centro"):
			continue
		var cell := Vector2i(8,13)
		for building: Dictionary in buildings:
			if building.kind == "training" and building.stage != "cancelled":
				cell = building.cell
				if int(building.id) == int(course.get("building", -1)): break
		_add(groups, reason, TranslationServer.translate("Formação: {role}").format({"role":role}), cell)
	var result: Array[Dictionary] = []
	for group: Dictionary in groups.values(): result.append(group)
	return result

static func _add(groups: Dictionary, reason: String, source: String, cell: Vector2i) -> void:
	if reason.is_empty(): return
	if not groups.has(reason):
		groups[reason] = {"reason":reason, "sources":[], "cells":[]}
	groups[reason].sources.append(source)
	groups[reason].cells.append(cell)
