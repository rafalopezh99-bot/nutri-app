import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_theme.dart';

class ListaCompraScreen extends StatefulWidget {
  const ListaCompraScreen({super.key});

  @override
  State<ListaCompraScreen> createState() => _ListaCompraScreenState();
}

class _ListaCompraScreenState extends State<ListaCompraScreen> {
  bool _isLoading = true;
  Map<String, List<String>> _categorias = {};
  Set<String> _marcados = {};

  // Base de palabras clave por categoría
  static const Map<String, List<String>> _keywords = {
    '🥩 Carnes': [
      'pollo', 'pechuga', 'muslo', 'ternera', 'cerdo', 'pavo', 'lomo',
      'filete', 'carne', 'jamón', 'chorizo', 'salchicha', 'costilla',
      'hamburguesa', 'cordero', 'conejo', 'pato', 'bacon', 'panceta',
    ],
    '🐟 Pescados y mariscos': [
      'salmón', 'atún', 'merluza', 'bacalao', 'sardina', 'dorada', 'lubina',
      'trucha', 'gambas', 'langostino', 'mejillón', 'calamar', 'pulpo',
      'pescado', 'boquerón', 'anchoa', 'rape', 'sepia', 'almeja',
    ],
    '🥦 Verduras y hortalizas': [
      'brócoli', 'espinaca', 'zanahoria', 'tomate', 'pepino', 'lechuga',
      'cebolla', 'pimiento', 'calabacín', 'berenjena', 'coliflor', 'apio',
      'puerro', 'alcachofa', 'espárrago', 'champiñón', 'seta', 'acelga',
      'remolacha', 'nabo', 'col', 'kale', 'aguacate', 'maíz', 'verdura',
      'ensalada', 'mediterránea', 'mixta',
    ],
    '🍎 Frutas': [
      'manzana', 'naranja', 'plátano', 'fresa', 'uva', 'pera', 'melocotón',
      'melón', 'sandía', 'kiwi', 'mango', 'piña', 'cereza', 'frambuesa',
      'arándano', 'granada', 'limón', 'mandarina', 'fruta', 'frutas',
      'bosque', 'frutos rojos',
    ],
    '🌾 Cereales y carbohidratos': [
      'arroz', 'pasta', 'pan', 'avena', 'quinoa', 'cuscús', 'macarrón',
      'espagueti', 'fideos', 'integral', 'trigo', 'centeno', 'tortilla',
      'tostada', 'cereales', 'muesli', 'granola', 'galleta', 'bizcocho',
    ],
    '🥚 Lácteos y huevos': [
      'leche', 'yogur', 'queso', 'huevo', 'mantequilla', 'nata', 'kéfir',
      'mozzarella', 'requesón', 'ricotta', 'parmesano', 'lácteo',
    ],
    '🫘 Legumbres': [
      'lenteja', 'garbanzo', 'judía', 'alubia', 'guisante', 'habas',
      'soja', 'edamame', 'legumbre', 'legumbres',
    ],
    '🥑 Grasas y frutos secos': [
      'aceite', 'nuez', 'almendra', 'avellana', 'pistacho', 'anacardo',
      'semilla', 'chía', 'lino', 'sésamo', 'mantequilla de cacahuete',
      'tahini', 'oliva',
    ],
  };

  @override
  void initState() {
    super.initState();
    _generarLista();
  }

  static DateTime _monday(DateTime d) =>
      d.subtract(Duration(days: d.weekday - 1));

  Future<void> _generarLista() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final weekStart = _monday(DateTime.now());
      final weekEnd = weekStart.add(const Duration(days: 6));

      final data = await Supabase.instance.client
          .from('weekly_plan')
          .select('description, meal_type, ingredients')
          .eq('client_id', userId)
          .gte('plan_date', weekStart.toIso8601String().substring(0, 10))
          .lte('plan_date', weekEnd.toIso8601String().substring(0, 10));

      // Map: nombre_lowercase → {display, grams total}
      final Map<String, Map<String, dynamic>> itemMap = {};

      for (final meal in data) {
        final rawIngredients = meal['ingredients'];

        if (rawIngredients is List && rawIngredients.isNotEmpty) {
          // ── Usar ingredientes explícitos ──────────────────────────────
          for (final ing in rawIngredients) {
            final name = ((ing['name'] as String?) ?? '').trim();
            if (name.isEmpty) continue;
            final gramsRaw = ing['grams'];
            final grams = gramsRaw is int
                ? gramsRaw
                : (gramsRaw is num ? gramsRaw.toInt() : null);
            final key = name.toLowerCase();

            if (itemMap.containsKey(key)) {
              final existing = itemMap[key]!;
              final existingGrams = existing['grams'] as int?;
              if (grams != null && existingGrams != null) {
                itemMap[key]!['grams'] = existingGrams + grams;
              } else if (grams != null) {
                itemMap[key]!['grams'] = grams;
              }
            } else {
              itemMap[key] = {'display': name, 'grams': grams};
            }
          }
        } else {
          // ── Fallback: adivinar por descripción ────────────────────────
          final descripcion =
              (meal['description'] as String? ?? '').toLowerCase();
          for (final kEntry in _keywords.entries) {
            for (final keyword in kEntry.value) {
              if (descripcion.contains(keyword.toLowerCase())) {
                final key = keyword.toLowerCase();
                itemMap.putIfAbsent(key, () => {
                  'display':
                      keyword[0].toUpperCase() + keyword.substring(1),
                  'grams': null,
                });
              }
            }
          }
        }
      }

      // Categorizar cada item
      final Map<String, Set<String>> encontrados = {};

      for (final entry in itemMap.entries) {
        final nameLower = entry.key;
        final display = entry.value['display'] as String;
        final grams = entry.value['grams'] as int?;
        final label = grams != null ? '$display (${grams}g)' : display;

        bool matched = false;
        for (final kEntry in _keywords.entries) {
          bool hit = false;
          for (final keyword in kEntry.value) {
            if (nameLower.contains(keyword.toLowerCase())) {
              hit = true;
              break;
            }
          }
          if (hit) {
            encontrados.putIfAbsent(kEntry.key, () => {});
            encontrados[kEntry.key]!.add(label);
            matched = true;
            break;
          }
        }

        if (!matched) {
          encontrados.putIfAbsent('🛍️ Otros', () => {});
          encontrados['🛍️ Otros']!.add(label);
        }
      }

      // Construir resultado ordenado
      final Map<String, List<String>> resultado = {};
      for (final cat in _keywords.keys) {
        if (encontrados.containsKey(cat) &&
            encontrados[cat]!.isNotEmpty) {
          resultado[cat] = encontrados[cat]!.toList()..sort();
        }
      }
      if (encontrados.containsKey('🛍️ Otros') &&
          encontrados['🛍️ Otros']!.isNotEmpty) {
        resultado['🛍️ Otros'] =
            encontrados['🛍️ Otros']!.toList()..sort();
      }

      setState(() => _categorias = resultado);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar la lista: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2))
          : _categorias.isEmpty
              ? Center(
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
                        child: const Icon(Icons.shopping_cart_outlined,
                            size: 30, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Sin plan semanal todavía',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tu nutricionista aún no ha añadido platos',
                        style:
                            TextStyle(fontSize: 13, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _categorias.length,
                  itemBuilder: (context, index) {
                    final categoria =
                        _categorias.keys.elementAt(index);
                    final items = _categorias[categoria]!;
                    return _CategoriaCard(
                      categoria: categoria,
                      items: items,
                      marcados: _marcados,
                      onToggle: (item) {
                        setState(() {
                          final key = '$categoria:$item';
                          if (_marcados.contains(key)) {
                            _marcados.remove(key);
                          } else {
                            _marcados.add(key);
                          }
                        });
                      },
                    );
                  },
                ),
    );
  }
}

class _CategoriaCard extends StatelessWidget {
  final String categoria;
  final List<String> items;
  final Set<String> marcados;
  final Function(String) onToggle;

  const _CategoriaCard({
    required this.categoria,
    required this.items,
    required this.marcados,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Text(
              categoria,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Container(height: 0.5, color: AppColors.border),
          ...items.map((item) {
            final key = '$categoria:$item';
            final marcado = marcados.contains(key);
            return GestureDetector(
              onTap: () => onToggle(item),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: item != items.last
                          ? AppColors.border
                          : Colors.transparent,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: marcado
                            ? AppColors.primary
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: marcado
                              ? AppColors.primary
                              : AppColors.border,
                          width: marcado ? 0 : 1,
                        ),
                      ),
                      child: marcado
                          ? const Icon(Icons.check_rounded,
                              size: 14, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      item,
                      style: TextStyle(
                        fontSize: 14,
                        color: marcado
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                        decoration: marcado
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
