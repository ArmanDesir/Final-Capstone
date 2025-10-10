import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/classroom_provider.dart';
import '../models/classroom.dart';
import 'create_classroom_screen.dart';
import 'classroom_details_screen.dart';

class ManageClassroomsScreen extends StatefulWidget {
  const ManageClassroomsScreen({super.key});

  @override
  State<ManageClassroomsScreen> createState() => _ManageClassroomsScreenState();
}

class _ManageClassroomsScreenState extends State<ManageClassroomsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Classroom> _filteredClassrooms = [];
  int _itemsPerPage = 10;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ClassroomProvider>(context, listen: false);
    provider.loadTeacherClassrooms().then((_) {
      _applyFilter();
    });

    _searchController.addListener(_applyFilter);
  }

  void _applyFilter() {
    final provider = Provider.of<ClassroomProvider>(context, listen: false);
    final query = _searchController.text.toLowerCase();

    setState(() {
      _currentPage = 1;
      _filteredClassrooms = provider.teacherClassrooms
          .where((c) => c.name.toLowerCase().contains(query) || (c.code?.toLowerCase().contains(query) ?? false))
          .toList();
    });
  }

  List<Classroom> _paginatedClassrooms() {
    final start = 0;
    final end = (_currentPage * _itemsPerPage).clamp(0, _filteredClassrooms.length);
    return _filteredClassrooms.sublist(start, end);
  }

  bool get _hasMore => _currentPage * _itemsPerPage < _filteredClassrooms.length;

  @override
  Widget build(BuildContext context) {
    final classroomProvider = Provider.of<ClassroomProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Classrooms')),
      body: classroomProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search classrooms...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _filteredClassrooms.isEmpty
                ? Center(
              child: Text(
                'No classrooms found.',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _paginatedClassrooms().length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _paginatedClassrooms().length) {
                  return TextButton(
                    onPressed: () {
                      setState(() {
                        _currentPage++;
                      });
                    },
                    child: const Text('Load More'),
                  );
                }

                final classroom = _paginatedClassrooms()[index];
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade100,
                      child: const Icon(Icons.class_, color: Colors.green),
                    ),
                    title: Text(
                      classroom.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Code: ${classroom.code ?? ''}\nStudents: ${classroom.studentIds.length}',
                    ),
                    isThreeLine: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ClassroomDetailsScreen(classroom: classroom),
                        ),
                      );
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () async {
                            await _showEditClassroomDialog(classroomProvider, classroom);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Classroom'),
                                content: const Text('Are you sure you want to delete this classroom?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await classroomProvider.deleteClassroom(classroom.id);
                              _applyFilter();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Create Classroom'),
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateClassroomScreen()),
          );
          if (created == true) {
            classroomProvider.loadTeacherClassrooms().then((_) => _applyFilter());
          }
        },
      ),
    );
  }

  Future<void> _showEditClassroomDialog(ClassroomProvider provider, Classroom classroom) async {
    final nameController = TextEditingController(text: classroom.name);
    final descController = TextEditingController(text: classroom.description);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Classroom'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Classroom Name'),
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await provider.updateClassroom(
                classroom.copyWith(
                  name: nameController.text,
                  description: descController.text,
                ),
              );
              Navigator.pop(context);
              _applyFilter();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
