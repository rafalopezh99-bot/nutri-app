import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../app_theme.dart';

class PerfilClienteScreen extends StatefulWidget {
  const PerfilClienteScreen({super.key});

  @override
  State<PerfilClienteScreen> createState() => _PerfilClienteScreenState();
}

class _PerfilClienteScreenState extends State<PerfilClienteScreen> {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _measurements = [];
  bool _isLoading = true;

  static const List<String> _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];
  static const List<String> _mesesCortos = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([_cargarPerfil(), _cargarMedidas()]);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarPerfil() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final data = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    if (mounted) setState(() => _profile = data);
  }

  Future<void> _cargarMedidas() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final data = await Supabase.instance.client
        .from('measurements')
        .select()
        .eq('client_id', userId)
        .order('created_at', ascending: true);
    if (mounted) {
      setState(() =>
          _measurements = List<Map<String, dynamic>>.from(data));
    }
  }

  // ── Avatar ─────────────────────────────────────────────────────────────────

  Future<void> _subirFoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 800,
    );
    if (picked == null) return;
    try {
      final bytes = await picked.readAsBytes();
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final ext = picked.name.split('.').last;
      final path = '$userId/avatar.$ext';
      await Supabase.instance.client.storage
          .from('profile-photos')
          .uploadBinary(path, bytes,
              fileOptions:
                  FileOptions(upsert: true, contentType: 'image/$ext'));
      final url = Supabase.instance.client.storage
          .from('profile-photos')
          .getPublicUrl(path);
      await Supabase.instance.client
          .from('profiles')
          .update({'avatar_url': url})
          .eq('id', userId);
      _cargarPerfil();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir foto: $e')),
      );
    }
  }

  // ── Editar perfil ──────────────────────────────────────────────────────────

  void _mostrarEditarPerfil() {
    final nameCtrl =
        TextEditingController(text: _profile?['full_name'] ?? '');
    DateTime? selectedDate;
    final existingBirth = _profile?['birth_date'] as String?;
    if (existingBirth != null) {
      try {
        selectedDate = DateTime.parse(existingBirth);
      } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
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
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Editar perfil',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 20),
              const Text('Nombre completo',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted)),
              const SizedBox(height: 8),
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Tu nombre y apellidos',
                  prefixIcon: Icon(Icons.person_outline_rounded,
                      size: 18, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Fecha de nacimiento',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate ?? DateTime(1990, 1, 1),
                    firstDate: DateTime(1940),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setModalState(() => selectedDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: selectedDate != null
                        ? AppColors.primaryDim
                        : AppColors.surface2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selectedDate != null
                          ? AppColors.primary.withOpacity(0.3)
                          : AppColors.border,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cake_outlined,
                          size: 18,
                          color: selectedDate != null
                              ? AppColors.primary
                              : AppColors.textMuted),
                      const SizedBox(width: 10),
                      Text(
                        selectedDate != null
                            ? '${selectedDate!.day} de ${_meses[selectedDate!.month - 1]} de ${selectedDate!.year}'
                            : 'Seleccionar fecha',
                        style: TextStyle(
                          fontSize: 14,
                          color: selectedDate != null
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _guardarPerfil(
                        name: nameCtrl.text.trim(),
                        birthDate: selectedDate);
                  },
                  child: const Text('Guardar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _guardarPerfil(
      {required String name, DateTime? birthDate}) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('profiles').update({
        if (name.isNotEmpty) 'full_name': name,
        'birth_date': birthDate != null
            ? '${birthDate.year}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}'
            : null,
      }).eq('id', userId);
      _cargarPerfil();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // ── Mediciones ─────────────────────────────────────────────────────────────

  void _mostrarAnadirMedida() {
    final weightCtrl = TextEditingController();
    final fatCtrl = TextEditingController();
    final waistCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
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
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Nueva medición',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            '${selectedDate.day} ${_mesesCortos[selectedDate.month - 1]} ${selectedDate.year}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Peso (kg) *',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textMuted)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: weightCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          decoration:
                              const InputDecoration(hintText: '70.5'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Grasa corporal (%)',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textMuted)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: fatCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          decoration:
                              const InputDecoration(hintText: '18.0'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cintura (cm)',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: waistCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(
                            decimal: true),
                    decoration:
                        const InputDecoration(hintText: '80.0'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text('* Campo obligatorio',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textMuted)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final weight =
                        double.tryParse(weightCtrl.text.trim());
                    if (weight == null) {
                      // Usar el contexto del Scaffold padre, no el del modal
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Introduce el peso (campo obligatorio)')),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    await _guardarMedida(
                      weightKg: weight,
                      bodyFatPct:
                          double.tryParse(fatCtrl.text.trim()),
                      waistCm:
                          double.tryParse(waistCtrl.text.trim()),
                      date: selectedDate,
                    );
                  },
                  child: const Text('Guardar medición'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _guardarMedida({
    required double weightKg,
    double? bodyFatPct,
    double? waistCm,
    required DateTime date,
  }) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('measurements').insert({
        'client_id': userId,
        'weight_kg': weightKg,
        'body_fat_pct': bodyFatPct,
        'waist_cm': waistCm,
        'created_at': date.toIso8601String(),
      });
      _cargarMedidas();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _eliminarMedida(String id) async {
    await Supabase.instance.client
        .from('measurements')
        .delete()
        .eq('id', id);
    _cargarMedidas();
  }

  void _confirmarEliminar(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        title: const Text('Eliminar medición',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        content: const Text(
            '¿Seguro que quieres eliminar esta medición?',
            style:
                TextStyle(fontSize: 14, color: AppColors.textMuted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _eliminarMedida(id);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _calcularEdad(String? birthDate) {
    if (birthDate == null) return '';
    try {
      final bd = DateTime.parse(birthDate);
      final now = DateTime.now();
      int age = now.year - bd.year;
      if (now.month < bd.month ||
          (now.month == bd.month && now.day < bd.day)) age--;
      return '$age años';
    } catch (_) {
      return '';
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final d = DateTime.parse(dateStr);
      return '${d.day} ${_mesesCortos[d.month - 1]} ${d.year}';
    } catch (_) {
      return '';
    }
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mi perfil'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppColors.border),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: _mostrarEditarPerfil,
            color: AppColors.textMuted,
            tooltip: 'Editar perfil',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _cargar,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAvatarSection(),
                    const SizedBox(height: 24),
                    _buildMedidasSection(),
                    if (_measurements.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildGraficas(),
                      const SizedBox(height: 24),
                      _buildHistorial(),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAvatarSection() {
    final name = _profile?['full_name'] ?? 'Sin nombre';
    final avatarUrl = _profile?['avatar_url'] as String?;
    final birthDate = _profile?['birth_date'] as String?;
    final edad = _calcularEdad(birthDate);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _subirFoto,
            child: Stack(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryDim,
                    border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                        width: 2),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: avatarUrl != null
                      ? Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              _getInitials(name),
                              style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            _getInitials(name),
                            style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary),
                          ),
                        ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.surface, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        size: 13, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          if (birthDate != null) ...[
            Text(
              () {
                try {
                  final d = DateTime.parse(birthDate);
                  return '${d.day} de ${_meses[d.month - 1]} de ${d.year}  ·  $edad';
                } catch (_) {
                  return '';
                }
              }(),
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textMuted),
            ),
          ] else ...[
            GestureDetector(
              onTap: _mostrarEditarPerfil,
              child: const Text(
                '+ Añadir fecha de nacimiento',
                style:
                    TextStyle(fontSize: 13, color: AppColors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMedidasSection() {
    final last =
        _measurements.isNotEmpty ? _measurements.last : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SectionLabel('Mis medidas'),
            const Spacer(),
            GestureDetector(
              onTap: _mostrarAnadirMedida,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded,
                        size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Añadir',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.monitor_weight_outlined,
                label: 'Peso',
                value: last?['weight_kg'] != null
                    ? '${last!['weight_kg']} kg'
                    : '—',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                icon: Icons.percent_rounded,
                label: 'Grasa',
                value: last?['body_fat_pct'] != null
                    ? '${last!['body_fat_pct']}%'
                    : '—',
                color: AppColors.amber,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                icon: Icons.straighten_rounded,
                label: 'Cintura',
                value: last?['waist_cm'] != null
                    ? '${last!['waist_cm']} cm'
                    : '—',
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        if (last != null) ...[
          const SizedBox(height: 8),
          Text(
            'Última medición: ${_formatDate(last['created_at'] as String?)}',
            style:
                const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
        if (_measurements.isEmpty) ...[
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _mostrarAnadirMedida,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primaryDim,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.2),
                    width: 0.5),
              ),
              child: const Column(
                children: [
                  Icon(Icons.add_circle_outline_rounded,
                      color: AppColors.primary, size: 28),
                  SizedBox(height: 8),
                  Text('Añade tu primera medición',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                  SizedBox(height: 4),
                  Text('Registra tu progreso y visualiza tu evolución',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textMuted),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGraficas() {
    final weightData = _measurements
        .where((m) => m['weight_kg'] != null)
        .map((m) => (m['weight_kg'] as num).toDouble())
        .toList();
    final fatData = _measurements
        .where((m) => m['body_fat_pct'] != null)
        .map((m) => (m['body_fat_pct'] as num).toDouble())
        .toList();
    final weightDates = _measurements
        .where((m) => m['weight_kg'] != null)
        .map((m) => _formatDate(m['created_at'] as String?))
        .toList();
    final fatDates = _measurements
        .where((m) => m['body_fat_pct'] != null)
        .map((m) => _formatDate(m['created_at'] as String?))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Evolución'),
        const SizedBox(height: 12),
        if (weightData.isNotEmpty)
          _ChartCard(
            title: 'Peso',
            unit: 'kg',
            values: weightData,
            dates: weightDates,
            color: AppColors.primary,
          ),
        if (weightData.isNotEmpty && fatData.isNotEmpty)
          const SizedBox(height: 12),
        if (fatData.isNotEmpty)
          _ChartCard(
            title: 'Grasa corporal',
            unit: '%',
            values: fatData,
            dates: fatDates,
            color: AppColors.amber,
          ),
      ],
    );
  }

  Widget _buildHistorial() {
    final reversed = _measurements.reversed.take(20).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Historial'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Column(
            children: reversed.asMap().entries.map((e) {
              final m = e.value;
              final isLast = e.key == reversed.length - 1;
              return _HistorialRow(
                date: _formatDate(m['created_at'] as String?),
                weight: m['weight_kg'] != null
                    ? '${m['weight_kg']} kg'
                    : null,
                fat: m['body_fat_pct'] != null
                    ? '${m['body_fat_pct']}%'
                    : null,
                waist: m['waist_cm'] != null
                    ? '${m['waist_cm']} cm'
                    : null,
                isLast: isLast,
                onEdit: () => _mostrarEditarMedida(m),
                onDelete: () => _confirmarEliminar(m['id']),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _mostrarEditarMedida(Map<String, dynamic> m) {
    final weightCtrl = TextEditingController(
        text: m['weight_kg']?.toString() ?? '');
    final fatCtrl = TextEditingController(
        text: m['body_fat_pct']?.toString() ?? '');
    final waistCtrl = TextEditingController(
        text: m['waist_cm']?.toString() ?? '');

    DateTime selectedDate = DateTime.now();
    try {
      if (m['created_at'] != null) {
        selectedDate = DateTime.parse(m['created_at'] as String);
      }
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
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
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Editar medición',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            '${selectedDate.day} ${_mesesCortos[selectedDate.month - 1]} ${selectedDate.year}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Peso (kg)',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textMuted)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: weightCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          decoration:
                              const InputDecoration(hintText: '70.5'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Grasa (%)',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textMuted)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: fatCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          decoration:
                              const InputDecoration(hintText: '18.0'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cintura (cm)',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: waistCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(
                            decimal: true),
                    decoration:
                        const InputDecoration(hintText: '80.0'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final weight =
                        double.tryParse(weightCtrl.text.trim());
                    if (weight == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('El peso es obligatorio')),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    await _actualizarMedida(
                      id: m['id'] as String,
                      weightKg: weight,
                      bodyFatPct:
                          double.tryParse(fatCtrl.text.trim()),
                      waistCm:
                          double.tryParse(waistCtrl.text.trim()),
                      date: selectedDate,
                    );
                  },
                  child: const Text('Guardar cambios'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _actualizarMedida({
    required String id,
    required double weightKg,
    double? bodyFatPct,
    double? waistCm,
    required DateTime date,
  }) async {
    try {
      await Supabase.instance.client.from('measurements').update({
        'weight_kg': weightKg,
        'body_fat_pct': bodyFatPct,
        'waist_cm': waistCm,
        'created_at': date.toIso8601String(),
      }).eq('id', id);
      _cargarMedidas();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}

// ─── Stat Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

// ─── Chart Card ────────────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final String title;
  final String unit;
  final List<double> values;
  final List<String> dates;
  final Color color;

  const _ChartCard(
      {required this.title,
      required this.unit,
      required this.values,
      required this.dates,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final current = values.last;
    final diff = values.length > 1 ? current - values.first : 0.0;
    final diffStr =
        diff >= 0 ? '+${diff.toStringAsFixed(1)}' : diff.toStringAsFixed(1);

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
          Row(
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const Spacer(),
              Text('${current.toStringAsFixed(1)} $unit',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: color)),
              if (values.length > 1) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: diff >= 0
                        ? AppColors.amberDim
                        : AppColors.primaryDim,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    diffStr,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: diff >= 0
                            ? AppColors.amber
                            : AppColors.primary),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: CustomPaint(
              painter: _LineChartPainter(values: values, color: color),
              size: Size.infinite,
            ),
          ),
          if (dates.length >= 2) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(dates.first,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textMuted)),
                if (dates.length > 2)
                  Text(dates[dates.length ~/ 2],
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textMuted)),
                Text(dates.last,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textMuted)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final Color color;

  const _LineChartPainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    const pH = 8.0, pTop = 8.0, pBottom = 4.0;
    final drawW = size.width - pH * 2;
    final drawH = size.height - pTop - pBottom;

    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = maxV - minV;

    List<Offset> pts = [];
    for (int i = 0; i < values.length; i++) {
      final x = pH +
          (values.length == 1
              ? drawW / 2
              : drawW * i / (values.length - 1));
      final norm = range == 0 ? 0.5 : (values[i] - minV) / range;
      pts.add(Offset(x, pTop + drawH * (1 - norm)));
    }

    if (pts.length > 1) {
      // Gradient fill
      final fill = Path()
        ..moveTo(pts.first.dx, size.height)
        ..lineTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        fill.lineTo(p.dx, p.dy);
      }
      fill
        ..lineTo(pts.last.dx, size.height)
        ..close();
      canvas.drawPath(
          fill,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withOpacity(0.18), color.withOpacity(0.0)],
            ).createShader(
                Rect.fromLTWH(0, 0, size.width, size.height)));

      // Line
      final line = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        line.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
          line,
          Paint()
            ..color = color
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round);
    }

    // Dots
    for (int i = 0; i < pts.length; i++) {
      final isLast = i == pts.length - 1;
      canvas.drawCircle(
          pts[i],
          isLast ? 5.0 : 3.0,
          Paint()
            ..color = isLast ? color : color.withOpacity(0.5)
            ..style = PaintingStyle.fill);
      if (isLast && pts.length > 1) {
        canvas.drawCircle(pts[i], 2.5,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.fill);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.values != values;
}

// ─── Historial Row ──────────────────────────────────────────────────────────────

class _HistorialRow extends StatelessWidget {
  final String date;
  final String? weight;
  final String? fat;
  final String? waist;
  final bool isLast;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _HistorialRow(
      {required this.date,
      this.weight,
      this.fat,
      this.waist,
      required this.isLast,
      required this.onEdit,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom:
                    BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Text(date,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted)),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (weight != null)
                  _DataChip(
                      label: weight!,
                      color: AppColors.primary,
                      bg: AppColors.primaryDim),
                if (fat != null)
                  _DataChip(
                      label: fat!,
                      color: AppColors.amber,
                      bg: AppColors.amberDim),
                if (waist != null)
                  _DataChip(
                      label: waist!,
                      color: AppColors.textMuted,
                      bg: AppColors.surface2),
              ],
            ),
          ),
          GestureDetector(
            onTap: onEdit,
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.edit_outlined,
                  size: 15, color: AppColors.textMuted),
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: const Padding(
              padding: EdgeInsets.only(left: 10),
              child: Icon(Icons.close_rounded,
                  size: 15, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _DataChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;

  const _DataChip(
      {required this.label,
      required this.color,
      required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }
}
