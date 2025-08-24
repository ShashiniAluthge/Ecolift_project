import 'package:flutter/material.dart';

class WasteType {
  final String name;
  final IconData icon;
  final String description;
  final Color color;

  const WasteType({
    required this.name,
    required this.icon,
    required this.description,
    required this.color,
  });
}

class ScheduledWasteTypeSelection extends StatefulWidget {
  const ScheduledWasteTypeSelection({super.key});

  @override
  State<ScheduledWasteTypeSelection> createState() =>
      _ScheduledWasteTypeSelectionState();
}

class _ScheduledWasteTypeSelectionState
    extends State<ScheduledWasteTypeSelection>
    with SingleTickerProviderStateMixin {
  final List<WasteType> wasteTypes = const [
    WasteType(
      name: 'Plastic',
      icon: Icons.local_drink,
      description: 'Bottles, containers, packaging',
      color: Color(0xFF4CAF50),
    ),
    WasteType(
      name: 'Paper',
      icon: Icons.description,
      description: 'Newspapers, cardboard, magazines',
      color: Color(0xFF8BC34A),
    ),
    WasteType(
      name: 'Glass',
      icon: Icons.wine_bar,
      description: 'Bottles, jars, broken glass',
      color: Color(0xFF009688),
    ),
    WasteType(
      name: 'Metal',
      icon: Icons.hardware,
      description: 'Cans, aluminum, scrap metal',
      color: Color(0xFF795548),
    ),
    WasteType(
      name: 'E-waste',
      icon: Icons.devices,
      description: 'Electronics, batteries, appliances',
      color: Color(0xFF607D8B),
    ),
    WasteType(
      name: 'Organic',
      icon: Icons.eco,
      description: 'Food waste, garden waste',
      color: Color(0xFF8D6E63),
    ),
  ];

  final Set<String> _selectedTypes = {};
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFA8E063), Color(0xFF56AB2F)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon:
                          const Icon(Icons.arrow_back_ios, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Select Waste Types',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Info Banner
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Select all types of waste you want to dispose of',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Waste Types Grid
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.1,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: wasteTypes.length,
                      itemBuilder: (context, index) {
                        final waste = wasteTypes[index];
                        final isSelected = _selectedTypes.contains(waste.name);

                        return Card(
                          elevation: isSelected ? 8 : 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedTypes.remove(waste.name);
                                } else {
                                  _selectedTypes.add(waste.name);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isSelected
                                      ? [
                                          waste.color.withValues(alpha: 0.1),
                                          waste.color.withValues(alpha: 0.2),
                                        ]
                                      : [
                                          Colors.white,
                                          Colors.white,
                                        ],
                                ),
                                border: Border.all(
                                  color: isSelected
                                      ? waste.color
                                      : Colors.grey.shade200,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? waste.color.withValues(alpha: 0.1)
                                          : Colors.grey.shade100,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      waste.icon,
                                      size: 32,
                                      color: isSelected
                                          ? waste.color
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Flexible(
                                    child: Text(
                                      waste.name,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? waste.color
                                            : Colors.grey.shade800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Flexible(
                                    child: Text(
                                      waste.description,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                        height: 1.4,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              // Continue Button
              Padding(
                padding: const EdgeInsets.all(24),
                child: ElevatedButton(
                  onPressed: _selectedTypes.isEmpty
                      ? null
                      : () {
                          Navigator.pushNamed(
                            context,
                            '/scheduled_pickup_datetime',
                            arguments: {
                              'selectedWasteTypes': _selectedTypes.toList(),
                            },
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF56AB2F),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    minimumSize: const Size(double.infinity, 0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: Text(
                    _selectedTypes.isEmpty
                        ? 'Select Waste Types'
                        : 'Continue to Schedule',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
