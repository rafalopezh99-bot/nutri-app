import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../app_theme.dart';
import 'lista_compra_screen.dart';
import 'perfil_cliente_screen.dart';

class HomeClienteScreen extends StatefulWidget {
  const HomeClienteScreen({super.key});

  @override
  State<HomeClienteScreen> createState() => _HomeClienteScreenState();
}

class _HomeClienteScreenState extends State<HomeClienteScreen> {
  int _selectedTab = 0;
  int _selectedDay = DateTime.now().weekday - 1;
  late DateTime _weekStart;
  bool _isLoading = true;
  List<Map<String, dynamic>> _meals = [];
  int _weeklyTotal = 0;
  int _weeklyCompleted = 0;
  List<Map<String, dynamic>> _measurements = [];
  Map<String, dynamic> _profile = {};

  final List<String> _days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
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

  @override
  void initState() {
    super.initState();
    _weekStart = _monday(DateTime.now());
    _cargarPlan();
    _cargarEstadisticasSemana();
    _cargarPerfil();
    _cargarMedidas();
  }

  Future<void> _cargarEstadisticasSemana() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final weekEnd = _weekStart.add(const Duration(days: 6));
      final data = await Supabase.instance.client
          .from('weekly_plan')
          .select('completed')
          .eq('client_id', userId)
          .gte('plan_date', _weekStart.toIso8601String().substring(0, 10))
          .lte('plan_date', weekEnd.toIso8601String().substring(0, 10));
      if (!mounted) return;
      setState(() {
        _weeklyTotal = data.length;
        _weeklyCompleted =
            data.where((m) => m['completed'] == true).length;
      });
    } catch (_) {}
  }

  Future<void> _cargarPerfil() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      if (!mounted) return;
      setState(() => _profile = data);
    } catch (_) {}
  }

  Future<void> _cargarMedidas() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final data = await Supabase.instance.client
          .from('measurements')
          .select()
          .eq('client_id', userId)
          .order('created_at', ascending: true);
      if (!mounted) return;
      setState(() =>
          _measurements = List<Map<String, dynamic>>.from(data));
    } catch (_) {}
  }

  Future<void> _cerrarSesion() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/');
  }

  Future<void> _cargarPlan() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final dateStr = _selectedDate.toIso8601String().substring(0, 10);
      final data = await Supabase.instance.client
          .from('weekly_plan')
          .select()
          .eq('client_id', userId)
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
        SnackBar(content: Text('Error al cargar el plan: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleCompleted(String mealId, bool current) async {
    final newValue = !current;
    setState(() {
      final idx = _meals.indexWhere((m) => m['id'] == mealId);
      if (idx != -1) _meals[idx]['completed'] = newValue;
    });
    await Supabase.instance.client
        .from('weekly_plan')
        .update({'completed': newValue})
        .eq('id', mealId);
    _cargarEstadisticasSemana();
  }

  Future<void> _subirFoto(String mealId) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1200,
    );
    if (picked == null) return;

    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last;
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final path = '$userId/$mealId.$ext';

      await Supabase.instance.client.storage
          .from('meal-photos')
          .uploadBinary(path, bytes,
              fileOptions:
                  FileOptions(upsert: true, contentType: 'image/$ext'));

      final url = Supabase.instance.client.storage
          .from('meal-photos')
          .getPublicUrl(path);

      await Supabase.instance.client
          .from('weekly_plan')
          .update({'photo_url': url})
          .eq('id', mealId);

      _cargarPlan();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir la foto: $e')),
      );
    }
  }

  Future<void> _setLiked(String mealId, bool? current, bool value) async {
    final newValue = current == value ? null : value;
    setState(() {
      final idx = _meals.indexWhere((m) => m['id'] == mealId);
      if (idx != -1) _meals[idx]['liked'] = newValue;
    });
    await Supabase.instance.client
        .from('weekly_plan')
        .update({'liked': newValue})
        .eq('id', mealId);
  }

  Future<void> _saveComment(String mealId, String comment) async {
    final value = comment.trim().isEmpty ? null : comment.trim();
    setState(() {
      final idx = _meals.indexWhere((m) => m['id'] == mealId);
      if (idx != -1) _meals[idx]['comment'] = value;
    });
    await Supabase.instance.client
        .from('weekly_plan')
        .update({'comment': value})
        .eq('id', mealId);
  }

  int get _completedCount =>
      _meals.where((m) => m['completed'] == true).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(const ['Inicio', 'Mi plan', 'La compra', 'Chat', 'Mi perfil'][_selectedTab]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppColors.border),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20),
            onPressed: _cerrarSesion,
            color: AppColors.textMuted,
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBody() {
    switch (_selectedTab) {
      case 0:
        return _buildInicio();
      case 1:
        return _buildPlan();
      case 2:
        return const ListaCompraScreen();
      case 3:
        return _buildProximamente('Chat con tu nutricionista');
      case 4:
        return const PerfilClienteScreen();
      default:
        return _buildPlan();
    }
  }

  Widget _buildInicio() {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        await Future.wait([
          _cargarPlan(),
          _cargarEstadisticasSemana(),
          _cargarPerfil(),
          _cargarMedidas(),
        ]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGreeting(),
            const SizedBox(height: 16),
            _buildProgressBanner(),
            if (_measurements.isNotEmpty) ...[
              const SizedBox(height: 20),
              const SectionLabel('Progreso'),
              _buildMedidasResumen(),
              const SizedBox(height: 10),
              _buildMiniGrafica(),
            ],
            const SizedBox(height: 20),
            const SectionLabel('Próxima comida'),
            _buildProximaComida(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    final fullName = _profile['full_name'];
    final nombre = (fullName is String && fullName.isNotEmpty)
        ? fullName.split(' ').first
        : '';
    final h = DateTime.now().hour;
    final saludo =
        h < 12 ? 'Buenos días' : h < 20 ? 'Buenas tardes' : 'Buenas noches';
    final now = DateTime.now();
    final meses = [
      '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    final dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
    final diaSemana = dias[now.weekday - 1];
    final fecha = '$diaSemana ${now.day} de ${meses[now.month]}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$saludo${nombre.isNotEmpty ? ', $nombre' : ''} 👋',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          fecha,
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildMedidasResumen() {
    final weights = _measurements
        .where((m) => m['weight_kg'] != null)
        .toList();
    if (weights.isEmpty) return const SizedBox.shrink();

    final lastPeso = (weights.last['weight_kg'] as num).toDouble();
    final firstPeso = (weights.first['weight_kg'] as num).toDouble();
    final cambio = lastPeso - firstPeso;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Peso actual',
            value: '${lastPeso.toStringAsFixed(1)} kg',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Cambio total',
            value:
                '${cambio > 0 ? '+' : ''}${cambio.toStringAsFixed(1)} kg',
            valueColor:
                cambio < 0 ? AppColors.primary : AppColors.amber,
          ),
        ),
        if (_measurements.any((m) => m['body_fat_pct'] != null)) ...[
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              label: 'Grasa corporal',
              value: () {
                final last = _measurements.lastWhere(
                    (m) => m['body_fat_pct'] != null,
                    orElse: () => {});
                if (last.isEmpty) return '—';
                return '${(last['body_fat_pct'] as num).toStringAsFixed(1)}%';
              }(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMiniGrafica() {
    final weights = _measurements
        .where((m) => m['weight_kg'] != null)
        .map((m) => (m['weight_kg'] as num).toDouble())
        .toList();
    if (weights.length < 2) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Evolución del peso',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${weights.length} registros',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            width: double.infinity,
            child: CustomPaint(
              painter: _SparklinePainter(values: weights),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${weights.first.toStringAsFixed(1)} kg',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted),
              ),
              Text(
                '${weights.last.toStringAsFixed(1)} kg',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProximaComida() {
    if (_meals.isEmpty) return const SizedBox.shrink();

    final now = TimeOfDay.now();
    final nowMin = now.hour * 60 + now.minute;

    Map<String, dynamic>? proxima;
    int? minDiff;

    for (final meal in _meals) {
      if (meal['completed'] == true) continue;
      final time = meal['scheduled_time'] as String?;
      if (time != null) {
        final parts = time.split(':');
        if (parts.length >= 2) {
          final mealMin = (int.tryParse(parts[0]) ?? 0) * 60 +
              (int.tryParse(parts[1]) ?? 0);
          final diff = mealMin - nowMin;
          if (diff >= 0 && (minDiff == null || diff < minDiff)) {
            minDiff = diff;
            proxima = meal;
          }
        }
      }
    }

    // Si no hay próxima por horario, primera sin completar
    if (proxima == null) {
      for (final meal in _meals) {
        if (meal['completed'] != true) {
          proxima = meal;
          break;
        }
      }
    }

    if (proxima == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primaryDim,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.primary.withOpacity(0.15), width: 0.5),
        ),
        child: const Row(
          children: [
            Text('🎉', style: TextStyle(fontSize: 20)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '¡Todas las comidas de hoy completadas!',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final timeRaw = proxima['scheduled_time'] as String?;
    String? timeLabel;
    if (timeRaw != null) {
      final parts = timeRaw.split(':');
      if (parts.length >= 2) {
        timeLabel =
            '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
      }
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedTab = 1),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primaryDim,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.restaurant_rounded,
                  size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        (proxima['meal_type'] ?? '').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (timeLabel != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          timeLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    proxima['description'] ?? '',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBanner() {
    if (_weeklyTotal == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryDim,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.primary.withOpacity(0.15), width: 0.5),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¡Hola! 👋',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Tu nutricionista está preparando tu plan semanal.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    final pct = (_weeklyCompleted / _weeklyTotal * 100).round();
    final bool finished = pct == 100;

    String emoji, headline, subtitle;
    Color bannerColor, borderColor, barColor;

    if (finished) {
      emoji = '🎉';
      headline = '¡Semana completada!';
      subtitle = 'Eres increíble. ¡Sigue así la próxima semana!';
      bannerColor = AppColors.primaryDim;
      borderColor = AppColors.primary.withOpacity(0.2);
      barColor = AppColors.primary;
    } else if (pct >= 50) {
      emoji = '🎯';
      headline = '¡Llevas el $pct%! Te queda poco';
      subtitle =
          '$_weeklyCompleted de $_weeklyTotal comidas completadas esta semana';
      bannerColor = AppColors.amberDim;
      borderColor = AppColors.amber.withOpacity(0.3);
      barColor = AppColors.amber;
    } else if (pct > 0) {
      emoji = '🔥';
      headline = '¡Llevas el $pct%! Sigue así';
      subtitle =
          '$_weeklyCompleted de $_weeklyTotal comidas completadas esta semana';
      bannerColor = AppColors.amberDim;
      borderColor = AppColors.amber.withOpacity(0.3);
      barColor = AppColors.amber;
    } else {
      emoji = '💪';
      headline = '¡Empieza hoy!';
      subtitle = 'Tienes $_weeklyTotal comidas planificadas esta semana';
      bannerColor = AppColors.primaryDim;
      borderColor = AppColors.primary.withOpacity(0.15);
      barColor = AppColors.primary;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  headline,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$pct%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: finished ? AppColors.primary : AppColors.amber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _weeklyCompleted / _weeklyTotal,
              backgroundColor: Colors.white.withOpacity(0.5),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 7,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildPlan() {
    return Column(
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
                  _cargarEstadisticasSemana();
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
                  _cargarEstadisticasSemana();
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
                final isToday = date.year == DateTime.now().year &&
                    date.month == DateTime.now().month &&
                    date.day == DateTime.now().day;
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
                      border: isToday && !isSelected
                          ? Border.all(color: AppColors.primary, width: 1.5)
                          : null,
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
                                : isToday
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                          ),
                        ),
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected
                                ? Colors.white.withOpacity(0.85)
                                : isToday
                                    ? AppColors.primary
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

        // Contenido
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
                              Icons.restaurant_menu_outlined,
                              size: 26,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Sin plan para este día',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tu nutricionista aún no ha añadido comidas',
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
                          return _MealCard(
                            meal: meal,
                            onToggleCompleted: () => _toggleCompleted(
                              meal['id'],
                              meal['completed'] ?? false,
                            ),
                            onSetLiked: (value) => _setLiked(
                              meal['id'],
                              meal['liked'],
                              value,
                            ),
                            onSubirFoto: () => _subirFoto(meal['id']),
                            onSaveComment: (comment) =>
                                _saveComment(meal['id'], comment),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildProximamente(String titulo) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.construction_rounded,
                size: 30, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Próximamente',
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        border:
            Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: (i) => setState(() => _selectedTab = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month_rounded),
            label: 'Plan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart_rounded),
            label: 'Compra',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            activeIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

// ─── Meal Card ──────────────────────────────────────────────────────────────

class _MealCard extends StatefulWidget {
  final Map<String, dynamic> meal;
  final VoidCallback onToggleCompleted;
  final Function(bool) onSetLiked;
  final VoidCallback onSubirFoto;
  final Future<void> Function(String) onSaveComment;

  const _MealCard({
    required this.meal,
    required this.onToggleCompleted,
    required this.onSetLiked,
    required this.onSubirFoto,
    required this.onSaveComment,
  });

  @override
  State<_MealCard> createState() => _MealCardState();
}

class _MealCardState extends State<_MealCard> {
  void _abrirComentario() {
    final existingComment = widget.meal['comment'] as String? ?? '';
    final controller = TextEditingController(text: existingComment);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
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
              const Text(
                'Comentario para el nutricionista',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.meal['description'] ?? '',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 3,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText:
                      'Ej: Me quedó un poco soso, lo comí tarde...',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    widget.onSaveComment(controller.text);
                  },
                  child: const Text('Guardar comentario'),
                ),
              ),
              if (existingComment.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      widget.onSaveComment('');
                    },
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.red),
                    child: const Text('Eliminar comentario'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

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

  void _verFotoCompleta(String url) {
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
              child: Image.network(
                url,
                fit: BoxFit.contain,
                width: double.infinity,
                errorBuilder: (_, __, ___) => const SizedBox(
                  height: 200,
                  child: Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: Colors.white54, size: 48),
                  ),
                ),
              ),
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
    final bool completed = widget.meal['completed'] ?? false;
    final bool? liked = widget.meal['liked'];
    final String? photoUrl = widget.meal['photo_url'];
    final String? comment = widget.meal['comment'] as String?;
    final String timeStr =
        _formatTime(widget.meal['scheduled_time'] as String?);

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
                // Tipo + horario + badge completado
                Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: GestureDetector(
                        onTap: _abrirComentario,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: (comment != null && comment.isNotEmpty)
                                ? AppColors.primaryDim
                                : AppColors.surface2,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            (comment != null && comment.isNotEmpty)
                                ? '💬 Ver comentario'
                                : '💬 Añadir comentario...',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            (widget.meal['meal_type'] ?? '').toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.8,
                            ),
                          ),
                          if (timeStr.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.schedule_rounded,
                                    size: 13,
                                    color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text(
                                  timeStr,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 110,
                      child: GestureDetector(
                        onTap: photoUrl != null
                            ? () => _verFotoCompleta(photoUrl)
                            : widget.onSubirFoto,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: photoUrl != null
                                ? AppColors.primaryDim
                                : AppColors.surface2,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            photoUrl != null ? '📷 Ver foto' : '📷 Añadir foto',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    widget.meal['description'] ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                ),
                if (completed) ...[
                  const SizedBox(height: 6),
                  const Center(child: AppBadge.green(text: '✓ Completado')),
                ],

                // Comentario existente
                if (comment != null && comment.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _abrirComentario,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(8),
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
                                color: AppColors.textMuted,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                          const Icon(Icons.edit_outlined,
                              size: 13, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Acciones
                Row(
                  children: [
                    _ActionButton(
                      label: completed ? '✓ Hecho' : '○ Marcar hecho',
                      active: completed,
                      activeColor: AppColors.primary,
                      activeBg: AppColors.primaryDim,
                      onTap: widget.onToggleCompleted,
                    ),
                    const Spacer(),
                    _ActionButton(
                      label: '👍',
                      active: liked == true,
                      activeColor: AppColors.primary,
                      activeBg: AppColors.primaryDim,
                      onTap: () => widget.onSetLiked(true),
                    ),
                    const SizedBox(width: 6),
                    _ActionButton(
                      label: '👎',
                      active: liked == false,
                      activeColor: AppColors.red,
                      activeBg: AppColors.redDim,
                      onTap: () => widget.onSetLiked(false),
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

// ─── Helpers ────────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final Color activeBg;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.active,
    required this.activeColor,
    required this.activeBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? activeBg : AppColors.surface2,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? activeColor : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatCard({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ─── Sparkline painter ───────────────────────────────────────────────────────

class _SparklinePainter extends CustomPainter {
  final List<double> values;

  _SparklinePainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 0.001 ? 1.0 : maxV - minV;

    final pad = 6.0;

    double px(int i) => i / (values.length - 1) * size.width;
    double py(double v) =>
        size.height - pad - ((v - minV) / range) * (size.height - pad * 2);

    final pts = List.generate(
        values.length, (i) => Offset(px(i), py(values[i])));

    // Gradient fill
    final fillPath = Path()
      ..moveTo(pts.first.dx, size.height)
      ..lineTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      fillPath.lineTo(pts[i].dx, pts[i].dy);
    }
    fillPath
      ..lineTo(pts.last.dx, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withOpacity(0.18),
            AppColors.primary.withOpacity(0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Line
    final linePath = Path()
      ..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      linePath.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Último punto destacado
    canvas.drawCircle(pts.last, 4.5, Paint()..color = AppColors.primary);
    canvas.drawCircle(pts.last, 2.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.values != values;
}
