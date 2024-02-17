import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<String> _savedFiles = []; // List to store saved file names
  List<String> _attendanceDirectories = []; // List to store attendance directory names

  @override
  void initState() {
    super.initState();
    _loadSavedFiles();
    _loadAttendanceDirectories();
  }

  // Load saved file names from the documents directory
  Future<void> _loadSavedFiles() async {
    try {
      Directory directory = await getApplicationDocumentsDirectory();
      final files = directory
          .listSync()
          .where((entity) => entity.path.endsWith('.csv'))
          .toList();
      setState(() {
        _savedFiles = files.map((file) => file.path.split('/').last).toList();
      });
    } catch (e) {
      print('Failed to load saved CSV files: $e');
    }
  }

// Load attendance directory names
  Future<void> _loadAttendanceDirectories() async {
    try {
      Directory directory = await getApplicationDocumentsDirectory();
      final attendanceDir = Directory('${directory.path}/attendance');
      if (await attendanceDir.exists()) {
        final directories = await _listSubdirectories(attendanceDir);
        setState(() {
          _attendanceDirectories = directories.map((dir) => dir.path.split('/').last).toList();
        });
      }
    } catch (e) {
      print('Failed to load attendance directories: $e');
    }
  }

// Recursively list subdirectories within a directory
  Future<List<Directory>> _listSubdirectories(Directory directory) async {
    List<Directory> subdirectories = [];
    final entities = directory.listSync();
    for (var entity in entities) {
      if (entity is Directory) {
        subdirectories.add(entity);
        subdirectories.addAll(await _listSubdirectories(entity));
      }
    }
    return subdirectories;
  }


  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('My App'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Classes'),
              Tab(text: 'Saved Attendance'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Classes Tab
            ListView.builder(
              itemCount: _savedFiles.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_savedFiles[index]),
                  onTap: () {
                    // Navigate to the bulk upload screen with the selected file name
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ViewClass(fileName: _savedFiles[index]),
                      ),
                    );
                  },
                );
              },
            ),
            ListView.builder(
              itemCount: _attendanceDirectories.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_attendanceDirectories[index]),
                  onTap: () {
                    // Navigate to the attendance details screen with the selected directory name
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AttendanceDetails(directoryName: _attendanceDirectories[index]),
                      ),
                    );
                    print(_attendanceDirectories[index]);
                  },
                );
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _pickFile,
          child: Icon(Icons.add),
        ),
        bottomNavigationBar: BottomAppBar(
          child: ElevatedButton(
            child: Tex,
          ),
        ),
      ),
    );
  }

  void _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      Directory directory = await getApplicationDocumentsDirectory();
      await file.copy('${directory.path}/${result.files.single.name}');
      setState(() {
        _savedFiles.add(result.files.single.name!);
      });
    } else {
      // User canceled the picker
    }
  }
}
class AttendanceDetails extends StatelessWidget {
  final String directoryName;

  const AttendanceDetails({Key? key, required this.directoryName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(directoryName),
      ),
      body: FutureBuilder(
        future: _loadAttendanceFiles(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          } else {
            List<String> attendanceFiles =
            snapshot.data as List<String>;
            return ListView.builder(
              itemCount: attendanceFiles.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(attendanceFiles[index]),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AttendanceDetailsPage(filePath: '${directoryName}/${attendanceFiles[index]}'),
                      ),
                    );
                    print(attendanceFiles[index]);
                  },
                );
              },
            );
          }
        },
      ),
    );
  }
  Future<List<String>> _loadAttendanceFiles() async {
    try {
      Directory directory = await getApplicationDocumentsDirectory();
      final attendanceDir = Directory('${directory.path}/attendance/$directoryName');
      if (await attendanceDir.exists()) {
        List<String> csvFiles = [];
        await _collectCsvFiles(attendanceDir, csvFiles);
        return csvFiles;
      } else {
        throw 'Attendance directory not found';
      }
    } catch (e) {
      throw 'Failed to load attendance files: $e';
    }
  }

  Future<void> _collectCsvFiles(Directory directory, List<String> csvFiles) async {
    final files = directory.listSync();
    for (var entity in files) {
      if (entity is Directory) {
        await _collectCsvFiles(entity, csvFiles);
      } else if (entity is File && entity.path.endsWith('.csv')) {
        csvFiles.add(entity.path.split('/').last);
      }
    }
  }

}
class AttendanceDetailsPage extends StatelessWidget {
  final String filePath;

  const AttendanceDetailsPage({Key? key, required this.filePath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance Details'),
      ),
      body: FutureBuilder(
        future: _loadAttendanceData(),
        builder: (context, AsyncSnapshot<List<List<dynamic>>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text('No data available'),
            );
          } else {
            List<List<dynamic>> attendanceData = snapshot.data!;
            return ListView.builder(
              itemCount: attendanceData.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text('${attendanceData[index][0]}'),
                  subtitle: Text('${attendanceData[index][1]}'),
                  // Add more details as needed
                );
              },
            );
          }
        },
      ),
    );
  }

  Future<List<List<dynamic>>> _loadAttendanceData() async {
    try {
      var documentsDirectory = await getApplicationDocumentsDirectory();
      var path = '${documentsDirectory.path}/attendance/$filePath';
      File file = File(path);
      print(file);
      // if (await file.exists()) {
        String contents = await file.readAsString();
        List<List<dynamic>> data = CsvToListConverter().convert(contents);
        return data;
    } catch (e) {
      throw 'Failed to load attendance data: $e';
    }
  }
}
class ViewClass extends StatelessWidget {
  final String fileName;

  const ViewClass({Key? key, required this.fileName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName),
      ),
      body: FutureBuilder(
        future: _loadData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          } else {
            List<List<dynamic>> data =
            snapshot.data as List<List<dynamic>>;
            return ListView.builder(
              itemCount: data.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(data[index][0].toString()),
                  subtitle: Text(data[index][1].toString()),
                );
              },
            );
          }
        },
      ),
    );
  }

  Future<List<List<dynamic>>> _loadData() async {
    try {
      Directory directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      if (await file.exists()) {
        String contents = await file.readAsString();
        return CsvToListConverter().convert(contents);
      } else {
        throw 'File not found';
      }
    } catch (e) {
      throw 'Failed to load data: $e';
    }
  }
}
class TakeAttendanceScreen extends StatefulWidget {
  final List<String> savedFiles;

  const TakeAttendanceScreen({Key? key, required this.savedFiles}) : super(key: key);

  @override
  _TakeAttendanceScreenState createState() => _TakeAttendanceScreenState();
}

class _TakeAttendanceScreenState extends State<TakeAttendanceScreen> {
  String? selectedClass;
  List<List<dynamic>> classData = [];
  TextEditingController subjectController = TextEditingController();
  TextEditingController timeController = TextEditingController();
  TextEditingController totimeController = TextEditingController();
  TextEditingController dateController = TextEditingController();
  String dropdownValue = 'Class 1'; // Default value for dropdown

  late bool isPresent; // Declare isPresent here

  @override
  void initState() {
    super.initState();
    isPresent = false; // Initialize isPresent
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Take Attendance'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Subject Name:',
              style: TextStyle(fontSize: 18.0),
            ),
            TextField(
              controller: subjectController,
              decoration: InputDecoration(
                hintText: 'Enter subject name',
              ),
            ),
            SizedBox(height: 20.0),
            Text(
              'From Time:',
              style: TextStyle(fontSize: 18.0),
            ),
            Text(timeController.text),
            TextButton(
              onPressed: () async {
                final TimeOfDay? pickedTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (pickedTime != null) {
                  setState(() {
                    // Update the dateController with the selected time
                    timeController.text = pickedTime.format(context);
                  });
                }
              },
              child: Text('Select Time'),
            ),
            Text(
              'TO Time:',
              style: TextStyle(fontSize: 18.0),
            ),
            Text(totimeController.text),
            TextButton(
              onPressed: () async {
                final TimeOfDay? pickedTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (pickedTime != null) {
                  setState(() {
                    // Update the dateController with the selected time
                    totimeController.text = pickedTime.format(context);
                  });
                }
              },
              child: Text('Select Time'),
            ),
            SizedBox(height: 20.0),
            Text(
              'Date',
              style: TextStyle(fontSize: 18.0),
            ),
            Text(dateController.text),
            TextButton(
              onPressed: () async {
                final DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (pickedDate != null) {
                  setState(() {
                    // Update the dateController with the selected date
                    dateController.text = pickedDate.toString().split(' ')[0]; // Format the date as needed (removing time)
                  });
                }
              },
              child: Text('Select Date'),
            ),
            SizedBox(height: 20.0),
            Text(
              'Select Class:',
              style: TextStyle(fontSize: 18.0),
            ),
            DropdownButton(
              value: selectedClass,
              items: widget.savedFiles.map((fileName) {
                return DropdownMenuItem(
                  value: fileName,
                  child: Text(
                    fileName.replaceAll('.csv', ''), // Remove the '.csv' extension
                  ),
                );
              }).toList(),
              onChanged: (value) async {
                setState(() {
                  selectedClass = value as String?;
                });
                await _loadClassData();
              },
            ),
            SizedBox(height: 20.0),
            if (classData.isNotEmpty) ...[
              Text(
                'Class Data:',
                style: TextStyle(fontSize: 18.0),
              ),
              SizedBox(height: 10.0),
              Expanded(
                child: ListView.builder(
                  itemCount: classData.length,
                  itemBuilder: (context, index) {
                    if (index < classData.length && index!=0) {
                      // Access the item at the current index
                      var currentItem = classData[index];
                      classData[index].add(true);
                      // Return a GestureDetector wrapping the ListTile
                      return GestureDetector(
                        onTap: () {
                          // Handle tap event here, for example, set isPresent

                          setState(() {
                            // Assuming isPresent is a boolean value in your class

                            classData[index][2]=!classData[index][2];
                          });
                          print(classData[index][2]);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: classData[index][2] ? Colors.green : Colors.red
                          ),
                          child: ListTile(
                            title: Text('${classData[index][0]}'), // Interpolate title
                            subtitle: Text('${classData[index][1]}'), // Interpolate subtitle
                          ),
                        )
                      );
                    } else {
                      return Container(); // or any other appropriate widget
                    }
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: ElevatedButton(
          onPressed: () {
            String subject = subjectController.text;
            String time = timeController.text;
            String date = dateController.text;
            String selectedClass = dropdownValue; // Assuming you store the selected class value in a variable
            _saveAttendance(subject, time, date, selectedClass);
          },
          child: Text('Save'),
        ),
      ),
    );
  }

  void _saveAttendance(String subject, String time, String date, String selectedClass) async {
    try {
      // Get the document directory
      Directory directory = await getApplicationDocumentsDirectory();
      String folderPath = '${directory.path}/attendance/$date';
      String filePath = '$folderPath/${selectedClass}_$subject.csv';

      // Create directory if it doesn't exist
      if (!(await Directory(folderPath).exists())) {
        await Directory(folderPath).create(recursive: true);
      }

      // Prepare attendance data
      List<List<dynamic>> attendanceRows = [
        ['Enrollment Number', 'Student Name', 'Is Present']
      ];
      for (var student in classData) {
        attendanceRows.add([
          student[0], // Enrollment Number
          student[1], // Student Name
          student[3], // Is Present
        ]);
      }

      // Convert data to CSV format
      String csv = const ListToCsvConverter().convert(attendanceRows);

      // Write CSV data to file
      File file = File(filePath);
      await file.writeAsString(csv);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attendance saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save attendance: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  Future<void> _loadClassData() async {
    if (selectedClass != null) {
      try {
        Directory directory = await getApplicationDocumentsDirectory();
        File file = File('${directory.path}/$selectedClass');
        String fileContent = await file.readAsString();
        List<List<dynamic>> csvTable = CsvToListConverter().convert(fileContent);
        setState(() {
          classData = csvTable;
        });
      } catch (e) {
        print('Failed to load class data: $e');
      }
    }
  }
}

