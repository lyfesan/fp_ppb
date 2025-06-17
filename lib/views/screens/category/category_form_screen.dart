import 'package:flutter/material.dart';

class CategoryFormScreen extends StatefulWidget {
  final String? initialName;
  final String? initialIcon;
  final bool isUpdate;
  final void Function(String name, String icon) onSubmit;

  const CategoryFormScreen({
    super.key,
    required this.onSubmit,
    this.initialName,
    this.initialIcon,
    this.isUpdate = false,
  });

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  late TextEditingController _textController;
  late String _selectedIcon;

  final List<String> _iconOptions = [
    'bills.png',
    'bonus.png',
    'chocolate.png',
    'duck.png',
    'education.png',
    'energy.png',
    'food.png',
    'gift.png',
    'handbody.png',
    'health.png',
    'iguana.png',
    'invest.png',
    'money.png',
    'pet_food.png',
    'pigeon.png',
    'popcorn.png',
    'sheep.png',
    'shirt.png',
    'shopping.png',
    'transportation.png',
    'water.png',
    'workout.png',
  ];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialName ?? '');
    _selectedIcon = widget.initialIcon ?? 'money.png';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isUpdate ? 'Update Category' : 'Add Category'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _textController,
              decoration: const InputDecoration(labelText: 'Category Name'),
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Choose an icon:', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: GridView.builder(
                shrinkWrap: true,
                scrollDirection: Axis.horizontal,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemCount: _iconOptions.length,
                itemBuilder: (context, index) {
                  final iconName = _iconOptions[index];
                  final isSelected = iconName == _selectedIcon;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = iconName),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected ? Colors.blueAccent : Colors.grey.shade300,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                      ),
                      child: Image.asset('assets/icons/$iconName', width: 40, height: 40),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                final name = _textController.text.trim();
                if (name.isNotEmpty) {
                  widget.onSubmit(name, _selectedIcon);
                  Navigator.pop(context);
                }
              },
              child: Text(widget.isUpdate ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }
}
