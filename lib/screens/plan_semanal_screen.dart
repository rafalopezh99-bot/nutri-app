import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_theme.dart';

class PlanSemanalScreen extends StatefulWidget {
  final Map<String, dynamic> cliente;

  const PlanSemanalScreen({super.key, required this.cliente});

  @override
  State<PlanSemanalScreen> createState() => _PlanSemanalScreenState();
}

class _PlanSemanalScreenState extends State<PlanSemanalScreen> {
  int _selectedDay = 0;
  late DateTime _weekStart;
  bool _isLoading = true;
  List<Map<String, dynamic>> _meals = [];

  final List<String> _days = [
    'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'
  ];
  final List<String> _daysFull = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
  ];

  static DateTime _monday(DateTime d) =>
      d.subtract(Duration(days: d.weekday - 1));

  DateTime get _selectedDate => _weekStart.add(Duration(days: _selectedDay));

  String _weekLabel() {
    const meses = [
      '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    final end = _weekStart.add(const Duration(days: 6));
    if (_weekStart.month == end.month) {
      return '${_weekStart.day}–${end.day} ${meses[end.month]}';
    }
    return '${_weekStart.day} ${meses[_weekStart.month]} – ${end.day} ${meses[end.month]}';
  }

  final List<String> _mealTypes = [
    'Desayuno', 'Almuerzo', 'Merienda', 'Cena'
  ];

  @override
  void initState() {
    super.initState();
    _weekStart = _monday(DateTime.now());
    _cargarPlan();
  }

  Future<void> _cargarPlan() async {
    setState(() => _isLoading = true);
    try {
      final dateStr = _selectedDate.toIso8601String().substring(0, 10);
      final data = await Supabase.instance.client
          .from('weekly_plan')
          .select()
          .eq('client_id', widget.cliente['id'])
          .eq('plan_date', dateStr);

      final mealOrder = ['Desayuno', 'Almuerzo', 'Merienda', 'Cena'];
      final sorted = List<Map<String, dynamic>>.from(data);
      sorted.sort((a, b) {
        final ai = mealOrder.indexOf(a['meal_type'] ?? '');
        final bi = mealOrder.indexOf(b['meal_type'] ?? '');
        return (ai == -1 ? 99 : ai).compareTo(bi == -1 ? 99 : bi);
      });

      setState(() => _meals = sorted);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _eliminarComida(String mealId) async {
    await Supabase.instance.client
        .from('weekly_plan')
        .delete()
        .eq('id', mealId);
    _cargarPlan();
  }

  // ── Copiar plan ──────────────────────────────────────────────────────────

  void _mostrarCopiarPlan() {
    if (_meals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No hay comidas en este día para copiar')),
      );
      return;
    }

    final Set<int> selectedTargets = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Copiar plan a otro día',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Copiando ${_meals.length} comidas del ${_daysFull[_selectedDay]}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Selecciona el día destino',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(_days.length, (i) {
                      if (i == _selectedDay) return const SizedBox.shrink();
                      final isSelected = selectedTargets.contains(i);
                      return GestureDetector(
                        onTap: () => setModalState(() {
                          if (isSelected) {
                            selectedTargets.remove(i);
                          } else {
                            selectedTargets.add(i);
                          }
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.surface2,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _daysFull[i],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Las comidas existentes en los días destino serán reemplazadas.',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedTargets.isEmpty
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              _ejecutarCopia(
                                  selectedTargets.toList());
                            },
                      child: Text(
                        selectedTargets.isEmpty
                            ? 'Selecciona un día'
                            : 'Copiar a ${selectedTargets.length} día${selectedTargets.length > 1 ? 's' : ''}',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _ejecutarCopia(List<int> targetDayIndices) async {
    try {
      for (final dayIdx in targetDayIndices) {
        final targetDay = _daysFull[dayIdx];
        // Borrar comidas existentes en el día destino
        final targetDate =
            _weekStart.add(Duration(days: dayIdx)).toIso8601String().substring(0, 10);
        await Supabase.instance.client
            .from('weekly_plan')
            .delete()
            .eq('client_id', widget.cliente['id'])
            .eq('plan_date', targetDate);

        // Insertar copia de cada comida
        for (final meal in _meals) {
          await Supabase.instance.client.from('weekly_plan').insert({
            'client_id': widget.cliente['id'],
            'day_of_week': _daysFull[dayIdx],
            'plan_date': targetDate,
            'meal_type': meal['meal_type'],
            'description': meal['description'],
            'scheduled_time': meal['scheduled_time'],
            'completed': false,
            'ingredients': meal['ingredients'] ?? [],
          });
        }
      }

      if (!mounted) return;
      final nombres =
          targetDayIndices.map((i) => _daysFull[i]).join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Plan copiado a: $nombres')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al copiar: $e')),
      );
    }
  }

  // ── Formulario añadir/editar ─────────────────────────────────────────────

  void _mostrarFormulario({Map<String, dynamic>? meal}) {
    final descController =
        TextEditingController(text: meal?['description'] ?? '');
    String selectedType = meal?['meal_type'] ?? _mealTypes[0];

    TimeOfDay? selectedTime;
    final existingTime = meal?['scheduled_time'] as String?;
    if (existingTime != null && existingTime.isNotEmpty) {
      final parts = existingTime.split(':');
      if (parts.length >= 2) {
        selectedTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }

    // Ingredientes
    List<Map<String, dynamic>> ingredients = [];
    final rawIng = meal?['ingredients'];
    if (rawIng is List) {
      ingredients = rawIng
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    final ingNameCtrl = TextEditingController();
    final ingGramsCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 28,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    meal == null ? 'Añadir comida' : 'Editar comida',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_daysFull[_selectedDay]} ${_selectedDate.day}/${_selectedDate.month}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 20),

                  // Tipo de comida
                  const Text(
                    'Tipo',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _mealTypes.map((type) {
                      final isSelected = type == selectedType;
                      return GestureDetector(
                        onTap: () =>
                            setModalState(() => selectedType = type),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.surface2,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            type,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Horario
                  const Text(
                    'Horario (opcional)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime ??
                            const TimeOfDay(hour: 8, minute: 0),
                        builder: (context, child) {
                          return MediaQuery(
                            data: MediaQuery.of(context).copyWith(
                                alwaysUse24HourFormat: true),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setModalState(() => selectedTime = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: selectedTime != null
                            ? AppColors.primaryDim
                            : AppColors.surface2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selectedTime != null
                              ? AppColors.primary.withOpacity(0.3)
                              : AppColors.border,
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 18,
                            color: selectedTime != null
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            selectedTime != null
                                ? '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                                : 'Sin horario asignado',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: selectedTime != null
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                            ),
                          ),
                          const Spacer(),
                          if (selectedTime != null)
                            GestureDetector(
                              onTap: () =>
                                  setModalState(() => selectedTime = null),
                              child: const Icon(Icons.close_rounded,
                                  size: 16, color: AppColors.textMuted),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Descripción
                  const Text(
                    'Descripción del plato',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descController,
                    maxLines: 2,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Ej: Pizza margarita, Macarrones boloñesa...',
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Ingredientes ───────────────────────────────────────────
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ingredientes',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              'Opcional · la lista de la compra los usará',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Chips ingredientes añadidos
                  if (ingredients.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: ingredients.asMap().entries.map((e) {
                        final idx = e.key;
                        final ing = e.value;
                        final grams = ing['grams'];
                        final label = grams != null
                            ? '${ing['name']} · ${grams}g'
                            : '${ing['name']}';
                        return Container(
                          padding: const EdgeInsets.only(
                              left: 10, top: 5, bottom: 5, right: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDim,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.primary.withOpacity(0.2),
                                width: 0.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => setModalState(
                                    () => ingredients.removeAt(idx)),
                                child: const Icon(Icons.close_rounded,
                                    size: 13, color: AppColors.primary),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Fila añadir ingrediente
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: ingNameCtrl,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                              hintText: 'Ingrediente'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 68,
                        child: TextField(
                          controller: ingGramsCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(hintText: 'g'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 44,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            final name = ingNameCtrl.text.trim();
                            if (name.isEmpty) return;
                            final grams = int.tryParse(
                                ingGramsCtrl.text.trim());
                            setModalState(() {
                              ingredients
                                  .add({'name': name, 'grams': grams});
                              ingNameCtrl.clear();
                              ingGramsCtrl.clear();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero),
                          child: const Icon(Icons.add_rounded, size: 20),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (descController.text.trim().isEmpty) return;
                        Navigator.pop(context);
                        await _guardarComida(
                          id: meal?['id'],
                          mealType: selectedType,
                          description: descController.text.trim(),
                          scheduledTime: selectedTime,
                          ingredients: ingredients,
                        );
                      },
                      child: Text(meal == null ? 'Añadir' : 'Guardar'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _guardarComida({
    String? id,
    required String mealType,
    required String description,
    TimeOfDay? scheduledTime,
    List<Map<String, dynamic>> ingredients = const [],
  }) async {
    final timeString = scheduledTime != null
        ? '${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}:00'
        : null;

    try {
      if (id == null) {
        await Supabase.instance.client.from('weekly_plan').insert({
          'client_id': widget.cliente['id'],
          'day_of_week': _daysFull[_selectedDay],
          'plan_date': _selectedDate.toIso8601String().substring(0, 10),
          'meal_type': mealType,
          'description': description,
          'scheduled_time': timeString,
          'completed': false,
          'ingredients': ingredients,
        });
      } else {
        await Supabase.instance.client.from('weekly_plan').update({
          'meal_type': mealType,
          'description': description,
          'scheduled_time': timeString,
          'ingredients': ingredients,
        }).eq('id', id);
      }
      _cargarPlan();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.cliente['full_name'] ?? 'Cliente';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Plan de $nombre'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppColors.border),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_rounded, size: 20),
            onPressed: _mostrarCopiarPlan,
            color: AppColors.textMuted,
            tooltip: 'Copiar plan a otro día',
          ),
        ],
      ),
      body: Column(
        children: [
          // Navegación de semana
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  color: AppColors.textMuted,
                  iconSize: 22,
                  onPressed: () {
                    setState(() => _weekStart =
                        _weekStart.subtract(const Duration(days: 7)));
                    _cargarPlan();
                  },
                ),
                Text(
                  _weekLabel(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  color: AppColors.textMuted,
                  iconSize: 22,
                  onPressed: () {
                    setState(() =>
                        _weekStart = _weekStart.add(const Duration(days: 7)));
                    _cargarPlan();
                  },
                ),
              ],
            ),
          ),
          Container(height: 0.5, color: AppColors.border),

          // Tabs de días con fecha
          Container(
            color: AppColors.surface,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_days.length, (i) {
                  final isSelected = i == _selectedDay;
                  final date = _weekStart.add(Duration(days: i));
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedDay = i);
                      _cargarPlan();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.surface2,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _days[i],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textMuted,
                            ),
                          ),
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected
                                  ? Colors.white.withOpacity(0.85)
                                  : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          Container(height: 0.5, color: AppColors.border),

          // Lista de comidas
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  )
                : _meals.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.surface2,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.add_circle_outline_rounded,
                                size: 28,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Sin comidas para este día',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Pulsa + para añadir la primera',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _cargarPlan,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _meals.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final meal = _meals[index];
                            return _NutriMealCard(
                              meal: meal,
                              onEdit: () =>
                                  _mostrarFormulario(meal: meal),
                              onDelete: () =>
                                  _confirmarEliminar(meal['id']),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormulario(),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _confirmarEliminar(String mealId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Eliminar comida',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary),
        ),
        content: const Text(
          '¿Seguro que quieres eliminar esta comida del plan?',
          style: TextStyle(fontSize: 14, color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _eliminarComida(mealId);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

// ─── Nutri Meal Card ─────────────────────────────────────────────────────────

class _NutriMealCard extends StatelessWidget {
  final Map<String, dynamic> meal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _NutriMealCard({
    required this.meal,
    required this.onEdit,
    required this.onDelete,
  });

  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return '';
    final parts = time.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = parts[1].padLeft(2, '0');
      return '${h.toString().padLeft(2, '0')}:$m';
    }
    return '';
  }

  void _verFoto(BuildContext context, String url) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (_, anim, __, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      ),
      pageBuilder: (_, __, ___) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(url, fit: BoxFit.contain,
                  width: double.infinity),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool completed = meal['completed'] ?? false;
    final bool? liked = meal['liked'];
    final String? photoUrl = meal['photo_url'];
    final String? comment = meal['comment'] as String?;
    final String timeStr = _formatTime(meal['scheduled_time'] as String?);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      (meal['meal_type'] ?? '').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (timeStr.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryDim,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule_rounded,
                                size: 10, color: AppColors.primary),
                            const SizedBox(width: 3),
                            Text(
                              timeStr,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (completed) const AppBadge.green(text: '✓ Hecho'),
                    if (liked == true) ...[
                      const SizedBox(width: 4),
                      const AppBadge.green(text: '👍 Le gusta'),
                    ],
                    if (liked == false) ...[
                      const SizedBox(width: 4),
                      AppBadge(
                        text: '👎 No le gusta',
                        color: AppColors.red,
                        bgColor: AppColors.redDim,
                      ),
                    ],
                    if (photoUrl != null) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => _verFoto(context, photoUrl),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDim,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('📷',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  meal['description'] ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),

                // Ingredientes
                Builder(builder: (_) {
                  final raw = meal['ingredients'];
                  if (raw is! List || raw.isEmpty) return const SizedBox.shrink();
                  final list = raw
                      .map((e) => Map<String, dynamic>.from(e as Map))
                      .toList();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: list.map((ing) {
                        final grams = ing['grams'];
                        final label = grams != null
                            ? '${ing['name']} · ${grams}g'
                            : '${ing['name']}';
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDim,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }),

                // Comentario del cliente
                if (comment != null && comment.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.amberDim,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.amber.withOpacity(0.3),
                          width: 0.5),
                    ),
                    child: Row(
                      children: [
                        const Text('💬',
                            style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            comment,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: onEdit,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Editar',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onDelete,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.redDim,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Eliminar',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.red,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
