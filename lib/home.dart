import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:azzahraly_motion/edit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool newProject = false;
  var formAddServo = GlobalKey<FormState>();

  Map data = {"servos": [], "motions": []};
  List recent = [];
  @override
  void initState() {
    getRecent();
    super.initState();
  }

  void getRecent() async {
    var pathApp = File((await getApplicationCacheDirectory()).path + '\\recent.json');

    if (pathApp.existsSync()) {
      recent = jsonDecode(pathApp.readAsStringSync());
      setState(() {});
    } else {
      pathApp.writeAsStringSync(jsonEncode([]));
    }
  }

  void updateRecent() async {
    var pathApp = File((await getApplicationCacheDirectory()).path + '\\recent.json');
    pathApp.writeAsStringSync(jsonEncode(recent));
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    return Scaffold(
        floatingActionButton: newProject
            ? FloatingActionButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Edit(
                      data: data,
                      directoryFile: "",
                    ),
                  ),
                ),
                child: const Icon(Icons.navigate_next),
              )
            : SizedBox(),
        body: Container(
          decoration: BoxDecoration(image: DecorationImage(image: AssetImage('assets/images/bg.png'), fit: BoxFit.cover)),
          child: Column(
            children: [
              Image.asset('assets/images/title.png'),
              Expanded(
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      width: newProject ? size.width / 2 - 200 : size.width / 2 - 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FilledButton(
                                style: FilledButton.styleFrom(minimumSize: Size.fromHeight(50)),
                                onPressed: () {
                                  setState(() {
                                    newProject = true;
                                  });
                                },
                                child: Text('New Project')),
                            const SizedBox(height: 10),
                            FilledButton(
                                style: FilledButton.styleFrom(minimumSize: Size.fromHeight(50)),
                                onPressed: () async {
                                  FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['azz']);

                                  // The result will be null, if the user aborted the dialog
                                  if (result != null) {
                                    if (!recent.contains(result.files.first.path)) {
                                      recent.add(result.files.first.path);
                                      updateRecent();
                                      setState(() {});
                                    }
                                    File file = File(result.files.first.path!);
                                    Map data = jsonDecode(file.readAsStringSync());
                                    Navigator.push(context, MaterialPageRoute(builder: (c) => Edit(data: data, directoryFile: file.path)));
                                  }
                                },
                                child: Text('Open Project')),
                            const SizedBox(height: 10),
                            FilledButton(style: FilledButton.styleFrom(minimumSize: Size.fromHeight(50)), onPressed: () {}, child: Text('Setting')),
                            const SizedBox(height: 10),
                            FilledButton(
                                style: FilledButton.styleFrom(minimumSize: Size.fromHeight(50)),
                                onPressed: () {
                                  showModalBottomSheet(
                                      context: context,
                                      showDragHandle: true,
                                      builder: (c) => Padding(
                                            padding: const EdgeInsets.all(20.0),
                                            child: ListView(
                                              children: [
                                                Center(child: Text('About Application', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
                                                Text('Azzahraly Motion is Software for making robot humanoid motion especially for servo XL-320 and MX-28')
                                              ],
                                            ),
                                          ));
                                },
                                child: Text('About')),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                    Container(width: 1, margin: EdgeInsets.symmetric(vertical: 20), color: Colors.blue),
                    newProject
                        ? AnimatedContainer(
                            duration: Duration(milliseconds: 200),
                            width: newProject ? size.width / 2 + 199 : size.width / 2,
                            height: size.height,
                            child: ListView(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    FilledButton(onPressed: addServo, child: Text('Add Servo')),
                                    const SizedBox(width: 10),
                                    IconButton.filled(
                                        onPressed: () {
                                          setState(() {
                                            newProject = false;
                                          });
                                        },
                                        icon: Icon(Icons.close)),
                                    const SizedBox(width: 20),
                                  ],
                                ),
                                for (int i = 0; i < data['servos'].length; i++)
                                  Card(
                                    child: ListTile(
                                      title: Text(data['servos'][i]['name']),
                                      subtitle: Text(data['servos'][i]['id'].toString()),
                                      trailing: IconButton(
                                          icon: Icon(Icons.delete),
                                          onPressed: () {
                                            setState(() {
                                              data['servos'].removeAt(i);
                                            });
                                          }),
                                    ),
                                  )
                              ],
                            ),
                          )
                        : Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
                              child: Column(
                                children: [
                                  Text('Recent Project', style: TextStyle(color: Colors.white, fontSize: 24)),
                                  Expanded(
                                    child: ListView.separated(
                                      itemCount: recent.length,
                                      separatorBuilder: (c, i) => Divider(color: Colors.white),
                                      itemBuilder: (c, i) => ListTile(
                                        title: Text(p.basename(recent[i]), style: TextStyle(color: Colors.white, fontSize: 20)),
                                        subtitle: Text(recent[i], style: TextStyle(color: Colors.white)),
                                        trailing: IconButton(
                                            onPressed: () {
                                              setState(() {
                                                recent.removeAt(i);
                                              });
                                              updateRecent();
                                            },
                                            icon: Icon(Icons.close, color: Colors.white)),
                                        onTap: () {
                                          data = jsonDecode(File(recent[i]).readAsStringSync());
                                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => Edit(data: data, directoryFile: recent[i])));
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                  ],
                ),
              ),
            ],
          ),
        ));
  }

  void addServo() {
    String name = "";
    int id = 0;
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text('Add Servo'),
              content: Form(
                key: formAddServo,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField(
                      hint: Text('Servo'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter some text';
                        }
                        return null;
                      },
                      value: null,
                      items: const [
                        DropdownMenuItem(value: 'xl-320', child: Text('XL-320')),
                        DropdownMenuItem(value: 'mx-28', child: Text('MX-28')),
                      ],
                      onChanged: (value) {
                        name = value!;
                      },
                    ),
                    DropdownButtonFormField(
                      hint: Text('ID'),
                      validator: (value) {
                        if (value == null) {
                          return 'Please enter some text';
                        }
                        return null;
                      },
                      value: null,
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('0')),
                        DropdownMenuItem(value: 1, child: Text('1')),
                        DropdownMenuItem(value: 2, child: Text('2')),
                        DropdownMenuItem(value: 3, child: Text('3')),
                        DropdownMenuItem(value: 4, child: Text('4')),
                        DropdownMenuItem(value: 5, child: Text('5')),
                        DropdownMenuItem(value: 6, child: Text('6')),
                        DropdownMenuItem(value: 7, child: Text('7')),
                        DropdownMenuItem(value: 8, child: Text('8')),
                        DropdownMenuItem(value: 9, child: Text('9')),
                        DropdownMenuItem(value: 10, child: Text('10')),
                        DropdownMenuItem(value: 11, child: Text('11')),
                        DropdownMenuItem(value: 12, child: Text('12')),
                        DropdownMenuItem(value: 13, child: Text('13')),
                        DropdownMenuItem(value: 14, child: Text('14')),
                        DropdownMenuItem(value: 15, child: Text('15')),
                        DropdownMenuItem(value: 16, child: Text('16')),
                        DropdownMenuItem(value: 17, child: Text('17')),
                        DropdownMenuItem(value: 18, child: Text('18')),
                        DropdownMenuItem(value: 19, child: Text('19')),
                        DropdownMenuItem(value: 20, child: Text('20')),
                        DropdownMenuItem(value: 21, child: Text('21')),
                        DropdownMenuItem(value: 22, child: Text('22')),
                        DropdownMenuItem(value: 23, child: Text('23')),
                        DropdownMenuItem(value: 24, child: Text('24')),
                        DropdownMenuItem(value: 25, child: Text('25')),
                      ],
                      onChanged: (value) {
                        id = value!;
                      },
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () {
                      if (formAddServo.currentState!.validate()) {
                        data['servos'].add({
                          "name": name,
                          "id": id,
                        });
                        Navigator.pop(context);
                        setState(() {});
                        print(data);
                      }
                    },
                    child: Text('Ok')),
                TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
              ],
            ));
  }
}
