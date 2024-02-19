import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
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
                    print(_savedFiles[index]);
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
          onPressed: (){
            Navigator.push(context, MaterialPageRoute(builder: (context)=>ZipUploadPage()));
          },
          child: Icon(Icons.add),
        ),
        bottomNavigationBar: BottomAppBar(
          child: ElevatedButton(
            child: Text("TAKE ATTENDANCE"),
            onPressed: (){
              Navigator.push(context, MaterialPageRoute(builder: (context)=>TakeAttendanceScreen(savedFiles: _savedFiles)));
            },
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


class ZipUploadPage extends StatefulWidget {
  @override
  _ZipUploadPageState createState() => _ZipUploadPageState();
}

class _ZipUploadPageState extends State<ZipUploadPage> {
  TextEditingController _FileNameController = TextEditingController();
  // TextEditingController _imageDirectoryNameController = TextEditingController();

  List<String> _savedFiles = [];
  List<File> _imageFiles = [];

  void _pickCSVFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result != null) {
      try {
        File file = File(result.files.single.path!);
        Directory directory = await getApplicationDocumentsDirectory();

        String fileName = _FileNameController.text.isNotEmpty
            ? _FileNameController.text
            : result.files.single.name!;

        // Create directory if it does not exist
        Directory filePathFinalDirectory = Directory('${directory.path}/$fileName');
        if (!filePathFinalDirectory.existsSync()) {
          filePathFinalDirectory.createSync(recursive: true);
        }

        // Copy file to the directory
        File filePathFinal = File('${filePathFinalDirectory.path}/$fileName');
        await file.copy(filePathFinal.path);

        setState(() {
          _savedFiles.add(fileName);
        });
        print(filePathFinal);
        print(filePathFinalDirectory);
        print(fileName);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV file saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save CSV file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      // User canceled the picker
    }
  }


  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result != null) {
      try {
        File file = File(result.files.single.path!);
        print('File loaded: ${file.path}');
        Directory directory = await getApplicationDocumentsDirectory();
        String fileName = result.files.single.name!;
        String filePath = '${directory.path}/$fileName';

        // Create directory if it does not exist
        if (!directory.existsSync()) {
          directory.createSync(recursive: true);
        }

        await file.copy(filePath);
        print('File copied to: $filePath');
        setState(() {
          _savedFiles.add(fileName);
        });

        // Unzip the uploaded file
        await _unzipAndSaveImages(File(filePath), directory);
      } catch (e) {
        print('Error copying file: $e');
      }
    } else {
      // User canceled the picker
    }
  }

  Future<void> _unzipAndSaveImages(File zipFile, Directory directory) async {
    try {
      // Create a directory to store the extracted images
      String imageDirectoryName =
      _FileNameController.text.isNotEmpty
          ? _FileNameController.text
          : 'images';
      print(imageDirectoryName);
      Directory imagesDirectory =
      Directory('${directory.path}/images/$imageDirectoryName');
      if (!imagesDirectory.existsSync()) {
        imagesDirectory.createSync();
      }

      // Read the zip file
      List<int> zipBytes = await zipFile.readAsBytes();
      Archive archive = ZipDecoder().decodeBytes(zipBytes);

      // Extract images from the zip file
      for (ArchiveFile file in archive) {
        if (file.isFile &&
            (file.name.toLowerCase().endsWith('.png') ||
                file.name.toLowerCase().endsWith('.jpg') ||
                file.name.toLowerCase().endsWith('.jpeg'))) {
          // Extract image file directly into imagesDirectory
          print(file.name);
          String fileName = file.name.split('/').last;
          print(fileName);
          File outFile = File('${imagesDirectory.path}/${fileName}');
          await outFile.writeAsBytes(file.content);
          print('Image extracted: ${outFile.path}');
          setState(() {
            _imageFiles.add(outFile); // Add image file to list
          });
        }
      }

      print('Images extracted and saved successfully!');
    } catch (e) {
      print('Error: $e');
    }
  }

  void _deleteFile(String fileName) {
    setState(() {
      _savedFiles.remove(fileName);
      _imageFiles.removeWhere((file) => file.path.endsWith(fileName));
    });
  }

  @override
  void dispose() {
    _FileNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Zip File Upload'),
      ),
      body: Column(
        children: <Widget>[
          ElevatedButton(
            onPressed: _pickFile,
            child: Text('Pick a Zip File'),
          ),
          ElevatedButton(
            onPressed: _pickCSVFile,
            child: Text('Pick a CSV File'),
          ),
          TextFormField(
            controller: _FileNameController,
            decoration: InputDecoration(labelText: 'CSV File Name'),
          ),
          SizedBox(height: 20),
          Text('Uploaded Files:'),
          SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: _savedFiles.length,
              itemBuilder: (context, index) {
                return LongPressDraggable(
                  data: _savedFiles[index],
                  feedback: Text(_savedFiles[index]),
                  child: ListTile(
                    title: Text(_savedFiles[index]),
                    onLongPress: () => _deleteFile(_savedFiles[index]),
                  ),
                  childWhenDragging: Container(),
                );
              },
            ),
          ),
          SizedBox(height: 20),
          Text('Images:'),
          SizedBox(height: 10),
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 4.0,
                mainAxisSpacing: 4.0,
              ),
              itemCount: _imageFiles.length,
              itemBuilder: (context, index) {
                return Image.file(_imageFiles[index]);
              },
            ),
          ),
        ],
      ),
    );
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
//TODO: WORK MORE ON ATTENDANCE DETIALS PAGE
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
class ViewClass extends StatefulWidget {
  final String fileName;

  const ViewClass({Key? key, required this.fileName}) : super(key: key);

  @override
  _ViewClassState createState() => _ViewClassState();
}

class _ViewClassState extends State<ViewClass> {
  late List<dynamic> csvData;
  late List<dynamic> imagePaths;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      Directory directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/${widget.fileName}/${widget.fileName}');
      print('File path: ${file.path}'); // Log the file path
      if (await file.exists()) {
        String contents = await file.readAsString();
        csvData = CsvToListConverter().convert(contents);

        // Load images from the directory
        imagePaths = [];
        Directory imageDir = Directory('${directory.path}/images/${widget.fileName.replaceAll(".csv", "")}');
        print(imageDir);

        if (await imageDir.exists()) {
          List<FileSystemEntity> imageFiles = imageDir.listSync();
          imagePaths = imageFiles.map((imageFile) => imageFile.path).toList();
          print(imagePaths);
        }

        setState(() {}); // Update the state to rebuild the UI with the loaded data
      } else {
        print('File not found'); // Log an error message if the file doesn't exist
        throw file;
      }
    } catch (e) {
      print('Error loading data: $e'); // Log any exceptions that occur
      throw 'Failed to load data: $e';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (csvData != null && imagePaths != null)
                // int i = 1; // Start index for csvData
                // int j = 0; // Start index for imagePaths
                for (int i = 0; i <= csvData.length && i <= imagePaths.length; i++)
                  Row(
                    children: [
                      if(i==0)
                        SizedBox()
                      else
                        Expanded(
                        child: Text(csvData[i][0].toString()), // Display CSV data
                        ),
                      SizedBox(width: 10), // Add some spacing between the text and image
                      if(i==0)
                        SizedBox()
                      else
                        Container(
                          height: 150,
                          width: 150,
                          child: Image.file(
                            File(imagePaths[i-1].toString()),
                            height: 150,
                            fit: BoxFit.fitWidth, // or BoxFit.cover depending on your preference
                          ),
                        )
                    ],
                  ),
            ],
          ),
        ),
      ),
    );
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
  // late List<String> imagePaths; // Add imagePaths

  late List<dynamic> csvData;
  late List<dynamic> imagePaths;

  @override
  void initState() {
    super.initState();
    // _loadData();
    csvData = [];
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

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
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
                  ],
                ),
                Column(
                  children: [
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
                  ],
                )

              ],
            ),
            SizedBox(height: 20.0),
            Text(
              'Date',
              style: TextStyle(fontSize: 18.0),
            ),
            Row(
              children: [
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
              ],
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
                // await _loadClassData();
                // await _loadImages();
                await _loadData();
              },
            ),
            SizedBox(height: 20.0),
            if (csvData.isNotEmpty) ...[
              // Text(
              //   'Class Data:',
              //   style: TextStyle(fontSize: 18.0),
              // ),
              // SizedBox(height: 10.0),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (csvData != null && imagePaths != null)
                      // int i = 1; // Start index for csvData
                      // int j = 0; // Start index for imagePaths
                        for (int i = 0; i <= csvData.length && i <= imagePaths.length; i++)
                          GestureDetector(
                            onTap: () {
                              // Handle tap event here, for example, set isPresent
                              setState(() {
                                // Assuming isPresent is a boolean value in your class
                                csvData[i][3] = !csvData[i][3];
                              });
                              print(csvData[i][3]);
                            },
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Container(
                               decoration: BoxDecoration(
                                 color: csvData[i][3] ? Colors.green : Colors.red,
                               ),
                               child:  Row(
                                 children: [
                                   if(i==0)
                                     SizedBox()
                                   else
                                     Expanded(
                                       child: Text(csvData[i][0].toString()), // Display CSV data
                                     ),
                                   SizedBox(width: 10), // Add some spacing between the text and image
                                   if(i==0)
                                     SizedBox()
                                   else
                                     Container(
                                       height: 150,
                                       width: 150,
                                       child: Image.file(
                                         File(imagePaths[i-1].toString()),
                                         height: 150,
                                         fit: BoxFit.fitWidth, // or BoxFit.cover depending on your preference
                                       ),
                                     )
                                 ],
                               ),
                              )
                            )
                          )
                    ],
                  ),
                  // ListView.builder(
                  //   itemCount: classData.length,
                  //   itemBuilder: (context, index) {
                  //     if (index < classData.length) {
                  //       // Access the item at the current index
                  //       var currentItem = classData[index];
                  //       classData[index].add(true);
                  //       // Return a GestureDetector wrapping the ListTile
                  //       return GestureDetector(
                  //         onTap: () {
                  //           // Handle tap event here, for example, set isPresent
                  //           setState(() {
                  //             // Assuming isPresent is a boolean value in your class
                  //             classData[index+1][3] = !classData[index][3+1];
                  //           });
                  //           print(classData[index+1][3]);
                  //         },
                  //         child: Padding(
                  //           padding: EdgeInsets.symmetric(vertical: 8),
                  //           child: Container(
                  //             decoration: BoxDecoration(
                  //               color: classData[index][3] ? Colors.green : Colors.red,
                  //             ),
                  //             child: Row(
                  //               children: [
                  //                   Image.file(
                  //                     File(imagePaths[index]), // Adjusted index here
                  //                     height: 150,
                  //                     width: 150,
                  //                     fit: BoxFit.fitWidth,
                  //                   ),
                  //
                  //                 SizedBox(width: 20),
                  //                 Column(
                  //                   children: [
                  //                     Text('${classData[index+1][0]}'),
                  //                     SizedBox(height: 30),
                  //                     Text('${classData[index+1][1]}'),
                  //                     // Text('${classData[index][2]}'),
                  //                   ],
                  //                 )
                  //               ],
                  //             ),
                  //           ),
                  //         ),
                  //       );
                  //     } else {
                  //       return Container(); // or any other appropriate widget
                  //     }
                  //   },
                  // ),
                ),
              )
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
      String filePath = '$folderPath/${selectedClass}_${subject}_${timeController.text}_${totimeController.text}.csv';

      // Create directory if it doesn't exist
      if (!(await Directory(folderPath).exists())) {
        await Directory(folderPath).create(recursive: true);
      }

      // Prepare attendance data
      List<List<dynamic>> attendanceRows = [
        ['Enrollment Number', 'Student Name', 'Phone Number','Is Present']
      ];
      for (var student in classData) {
        attendanceRows.add([
          student[0], // Enrollment Number
          student[1], // Student Name
          student[2], // Phone Number
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
  //
  // Future<void> _loadClassData() async {
  //   if (selectedClass != null) {
  //     try {
  //       Directory directory = await getApplicationDocumentsDirectory();
  //
  //       // Load CSV data
  //       File file = File('${directory.path}/$selectedClass/$selectedClass');
  //       String fileContent = await file.readAsString();
  //       List<List<dynamic>> csvTable = CsvToListConverter().convert(fileContent);
  //       setState(() {
  //         classData = csvTable;
  //       });
  //
  //     } catch (e) {
  //       print('Failed to load class data: $e');
  //     }
  //   }
  // }
  Future<void> _loadData() async {
    try {
      Directory directory = await getApplicationDocumentsDirectory();
      File file = File('${directory.path}/$selectedClass/$selectedClass');
      print('File path: ${file.path}'); // Log the file path
      if (await file.exists()) {
        String contents = await file.readAsString();
        csvData = CsvToListConverter().convert(contents);
        if (csvData.isNotEmpty) {
          // Check if index 3 exists in each row of classData
          for (int i = 0; i < csvData.length; i++) {
            if (csvData[i].length <= 3) {
              // If index 3 does not exist, add it and set it to false
              csvData[i].add(false); // Assuming you want to initialize it as false
            }
          }
        }
        // Load images from the directory
        imagePaths = [];
        Directory imageDir = Directory('${directory.path}/images/${selectedClass.toString().replaceAll(".csv", "")}');
        print(imageDir);

        if (await imageDir.exists()) {
          List<FileSystemEntity> imageFiles = imageDir.listSync();
          imagePaths = imageFiles.map((imageFile) => imageFile.path).toList();
          print(imagePaths);
        }

        setState(() {}); // Update the state to rebuild the UI with the loaded data
      } else {
        print('File not found'); // Log an error message if the file doesn't exist
        throw file;
      }
    } catch (e) {
      print('Error loading data: $e'); // Log any exceptions that occur
      throw 'Failed to load data: $e';
    }
  }
  _loadImages() async {
    print("Image loading start");
    if ( selectedClass!= null){
      Directory directory = await getApplicationDocumentsDirectory();
      print(directory);
      // Load image paths
      Directory imageDir = Directory('${directory.path}/images/${selectedClass?.replaceAll(".csv", "")}');
      print(imageDir);
      if (await imageDir.exists()) {
        List<FileSystemEntity> imageFiles = imageDir.listSync();
        imagePaths = imageFiles.map((imageFile) => imageFile.path).toList();
        print(imagePaths);
        setState(() {}); // Update the state to rebuild the UI with the loaded image paths
      }
    }
  }
}
