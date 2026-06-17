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
  int _selectedTab = 1;
  int _selectedDay = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _meals = [];
  int _weeklyTotal = 0;
  int _weeklyCompleted = 0;

  final List<String> _days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  final List<String> _daysFull = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
  ];

  @override
  void initState() {
    super.initState();
    _cargarPlan();
    _cargarEstadisticasSemana();
  }

  Future<void> _cargarEstadisticasSemana() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final data = await Supabase.instance.client
          .from('weekly_plan')
          .select('completed')
          .eq('client_id', userId);
      if (!mounted) return;
      setState(() {
        _weeklyTotal = data.length;
        _weeklyCompleted =
            data.where((m) => m['completed'] == true).length;
      });
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
      final data = await Supabase.instance.client
          .from('weekly_plan')
          .select()
          .eq('client_id', userId)
          .eq('day_of_week', _daysFull[_selectedDay]);

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
        title: const Text('Mi plan'),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProgressBanner(),
          const SizedBox(height: 20),
          const SectionLabel('Resumen de hoy'),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Comidas hechas hoy',
                  value: '$_completedCount/${_meals.length}',
                ),
              ),
            ],
          ),
        ],
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
        // Tabs de días
        Container(
          color: AppColors.surface,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_days.length, (i) {
                final isSelected = i == _selectedDay;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedDay = i);
                    _cargarPlan();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.surface2,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _days[i],
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
          // Foto si existe
          if (photoUrl != null)
            GestureDetector(
              onTap: widget.onSubirFoto,
              child: Image.network(
                photoUrl,
                width: double.infinity,
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tipo + horario + badge completado
                Row(
                  children: [
                    Text(
                      (widget.meal['meal_type'] ?? '').toUpperCase(),
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
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule_rounded,
                                size: 10,
                                color: AppColors.textMuted),
                            const SizedBox(width: 3),
                            Text(
                              timeStr,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (completed)
                      const AppBadge.green(text: '✓ Completado'),
                  ],
                ),

                const SizedBox(height: 6),
                Text(
                  widget.meal['description'] ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),

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
                      label: '💬',
                      active: comment != null && comment.isNotEmpty,
                      activeColor: AppColors.primary,
                      activeBg: AppColors.primaryDim,
                      onTap: _abrirComentario,
                    ),
                    const SizedBox(width: 6),
                    _ActionButton(
                      label: photoUrl != null ? '📷 Ver foto' : '📷',
                      active: photoUrl != null,
                      activeColor: AppColors.primary,
                      activeBg: AppColors.primaryDim,
                      onTap: widget.onSubirFoto,
                    ),
                    const SizedBox(width: 6),
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
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? activeBg : AppColors.surface2,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
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

  const _StatCard({required this.label, required this.value});

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
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
