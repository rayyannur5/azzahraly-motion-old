import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:azzahraly_motion/home.dart';
import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:keymap/keymap.dart';
import 'package:path_provider/path_provider.dart';

// ignore: must_be_immutable
class Edit extends StatefulWidget {
  Edit({super.key, required this.data, required this.directoryFile});
  Map data;
  String directoryFile;

  @override
  State<Edit> createState() => _EditState();
}

class _EditState extends State<Edit> {
  int openedMotion = -1;
  int openedStep = -1;
  Map tempData = {};
  List servos = [];
  List selectedServo = [];
  String port = "";
  SerialPort? serialPort;
  SerialPortReader? reader;

  @override
  void initState() {
    if (widget.directoryFile != "") {
      hackyDeepCopy(widget.data).then((value) {
        setState(() {
          tempData = value;
        });
      });
    }
    super.initState();
  }

  void send(String data) {
    data = "*$data#";
    List<int> codeUnits = data.codeUnits;
    var list = Uint8List.fromList(codeUnits);

    serialPort!.write(list);
  }

  String command = "";
  void serial(_port) {
    setState(() {
      port = _port;
    });
    serialPort = SerialPort(port);
    serialPort!.openReadWrite();

    reader = SerialPortReader(serialPort!);

    send('C');

    reader!.stream.listen((event) {
      String temp = String.fromCharCodes(event);

      command += temp;
      if (command.endsWith('#')) {
        command = command.substring(0, command.length - 1);

        Map data = jsonDecode(command);

        print(data);

        if (data['type'] == 'C') {
          selectedServo = [];
          for (var servo in data['data']) {
            selectedServo.add({
              'id': servo['id'],
              'selected': false,
            });
          }
          setState(() {
            servos = data['data'];
          });
        } else if (data['type'] == 'R') {
          for (int i = 0; i < data['data'].length; i++) {
            for (int j = 0; j < servos.length; j++) {
              if (servos[j]['id'] == data['data'][i]['id']) {
                servos[j] = data['data'][i];
                break;
              }
            }
          }
          setState(() {});
        } else if (data['type'] == 'F') {
          for (int i = 0; i < data['data'].length; i++) {
            for (int j = 0; j < servos.length; j++) {
              if (servos[j]['id'] == data['data'][i]['id']) {
                servos[j] = data['data'][i];
                break;
              }
            }
          }
          setState(() {});
        }

        command = "";
      }
    }).onError(
      (_) {
        setState(() {
          port = "";
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connection failed')));
      },
    );
  }

  void saveData() async {
    if (widget.directoryFile != "") {
      File(widget.directoryFile).writeAsStringSync(jsonEncode(widget.data));
      tempData = await hackyDeepCopy(widget.data);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save successfully'), duration: Duration(milliseconds: 100)));
    } else {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Please select an output file:',
        allowedExtensions: ['azz'],
        type: FileType.custom,
        fileName: 'motion',
      );

      if (outputFile != null) {
        widget.directoryFile = outputFile + '.azz';
        File(widget.directoryFile).writeAsStringSync(jsonEncode(widget.data));
        tempData = await hackyDeepCopy(widget.data);
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save successfully'), duration: Duration(milliseconds: 100)));

        var pathApp = File((await getApplicationCacheDirectory()).path + '\\recent.json');

        if (pathApp.existsSync()) {
          List recent = jsonDecode(pathApp.readAsStringSync());
          recent.add(widget.directoryFile);
          pathApp.writeAsStringSync(jsonEncode(recent));
        }
      }
    }
  }

  Future<T> hackyDeepCopy<T>(T object) async => await (ReceivePort()..sendPort.send(object)).first as T;

  @override
  Widget build(BuildContext context) {
    return KeyboardWidget(
      bindings: [
        KeyAction(LogicalKeyboardKey.keyS, 'Save motion', saveData, isControlPressed: true),
        KeyAction(LogicalKeyboardKey.keyA, 'Select all', () {
          for (int i = 0; i < selectedServo.length; i++) {
            selectedServo[i]['selected'] = true;
          }
          setState(() {});
        }, isControlPressed: true),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text('Azzahraly Motion'),
          backgroundColor: Color(0xff14708B),
          foregroundColor: Colors.white,
          leading: IconButton(icon: Icon(Icons.arrow_back_outlined), onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => Home()))),
          actions: [
            Text(widget.directoryFile),
            Text(tempData.toString() == widget.data.toString() ? "" : "*"),
            const SizedBox(width: 20),
            IconButton.filled(onPressed: saveData, color: Colors.white, icon: Icon(Icons.save)),
            const SizedBox(width: 20),
            IconButton.filled(onPressed: port == "" ? connectDevices : disconnectDevices, icon: Icon(port == "" ? Icons.usb : Icons.usb_off)),
            const SizedBox(width: 30)
          ],
        ),
        body: Container(
          decoration: BoxDecoration(image: DecorationImage(image: AssetImage('assets/images/bg.png'), fit: BoxFit.cover)),
          child: Column(
            children: [
              header(),
              Expanded(
                child: Row(
                  children: [
                    motions(),
                    steps(),
                    stepEditor(),
                    poseOfStep(),
                    sendAndGetWidget(),
                    poseOfRobot(),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget header() {
    return Padding(
      padding: EdgeInsets.all(10),
      child: Row(
        children: [
          Container(height: 36, margin: EdgeInsets.all(5), child: FilledButton.icon(onPressed: addMotion, icon: Icon(Icons.add), label: Text('New Motion'))),
          openedMotion != -1
              ? Row(
                  children: [
                    Container(
                      height: 36,
                      alignment: Alignment.centerLeft,
                      margin: EdgeInsets.only(left: 10),
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                      child: Text(widget.data['motions'][openedMotion]['name']),
                    ),
                    const SizedBox(width: 5),
                    IconButton.filled(
                        onPressed: () {
                          if (port == "") {
                            connectDevices();
                          }
                        },
                        icon: Icon(Icons.play_arrow)),
                    const SizedBox(width: 5),
                    IconButton.filled(onPressed: deleteMotion, icon: Icon(Icons.delete)),
                    const SizedBox(width: 5),
                    IconButton.filled(onPressed: updateNameMotion, icon: Icon(Icons.edit)),
                    const SizedBox(width: 5),
                    IconButton.filled(
                        onPressed: () {
                          setState(() {
                            openedMotion = -1;
                            openedStep = -1;
                          });
                        },
                        icon: Icon(Icons.close)),
                  ],
                )
              : SizedBox(),
          Spacer(),
          const SizedBox(width: 20),
          IconButton.filled(
              onPressed: () {
                if (port == "") {
                  connectDevices();
                } else {
                  String tempStr = "F";
                  for (var servo in selectedServo) {
                    if (servo['selected']) {
                      tempStr += '${servo['id']},';
                    }
                  }

                  send(tempStr);
                }
              },
              icon: Icon(Icons.lightbulb_outline)),
          const SizedBox(width: 5),
          IconButton.filled(
              onPressed: () {
                if (port == "") {
                  connectDevices();
                } else {
                  String tempStr = "R";
                  for (var servo in selectedServo) {
                    if (servo['selected']) {
                      tempStr += '${servo['id']},';
                    }
                  }

                  send(tempStr);
                }
              },
              icon: Icon(Icons.lightbulb_sharp)),
          const SizedBox(width: 5),
          IconButton.filled(
              onPressed: () {
                for (int i = 0; i < selectedServo.length; i++) {
                  selectedServo[i]['selected'] = false;
                }
                setState(() {});
              },
              icon: Icon(Icons.clear_all)),
        ],
      ),
    );
  }

  void connectDevices() {
    showDialog(
        context: context,
        builder: (c) => StatefulBuilder(builder: (context, set) {
              return AlertDialog(
                title: Text('Connect the Devices'),
                content: Column(
                  // mainAxisSize: MainAxisSize.min,
                  children: [
                    for (String address in SerialPort.availablePorts)
                      ListTile(
                        title: Text(address),
                        selectedTileColor: Colors.blue,
                        selectedColor: Colors.white,
                        onTap: () {
                          serial(address);
                          Navigator.pop(context);
                        },
                      ),
                  ],
                ),
                actions: [
                  TextButton(
                      onPressed: () {
                        set(() {});
                      },
                      child: Text('Refresh')),
                  TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
                ],
              );
            }));
  }

  void disconnectDevices() {
    setState(() {
      port = "";
    });

    reader!.close();
    serialPort!.close();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Device Disconnected')));
  }

  Widget motions() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Color.fromARGB(200, 124, 191, 219),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Stack(
              children: <Widget>[
                // Stroked text as border.
                Text(
                  'Motion Units',
                  style: TextStyle(
                    fontSize: 20,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 3
                      ..color = Colors.black,
                  ),
                ),
                // Solid text as fill.
                Text(
                  'Motion Units',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.grey[300],
                  ),
                ),
              ],
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('No', style: TextStyle(color: Colors.white)),
                Text('Motion', style: TextStyle(color: Colors.white)),
                Text('Next', style: TextStyle(color: Colors.white)),
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: widget.data['motions'].length,
                itemBuilder: (context, index) => Row(
                  children: [
                    Container(
                        height: 36,
                        width: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Color(0XFFDADADA),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text((index + 1).toString())),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: Material(
                          color: openedMotion == index ? Color(0xff219EBC) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              setState(() {
                                openedMotion = index;
                                openedStep = -1;
                              });
                            },
                            child: Container(
                              height: 36,
                              padding: EdgeInsets.only(left: 10),
                              alignment: Alignment.centerLeft,
                              child: Text(widget.data['motions'][index]['name'], style: TextStyle(color: openedMotion == index ? Colors.white : Colors.black)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Material(
                      color: Color(0XFFDADADA),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: () async {
                          int temp = await numEditor(widget.data['motions'][index]['next']);
                          setState(() {
                            widget.data['motions'][index]['next'] = temp;
                          });
                        },
                        child: Container(
                          height: 36,
                          width: 36,
                          alignment: Alignment.center,
                          child: Text(widget.data['motions'][index]['next'].toString()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void addMotion() {
    var controller = TextEditingController();
    var formState = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Add Motion'),
        content: Form(
          key: formState,
          child: TextFormField(
            autofocus: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter some text';
              }
              return null;
            },
            controller: controller,
            onEditingComplete: () {
              if (formState.currentState!.validate()) {
                widget.data['motions'].add({
                  "name": controller.text,
                  "steps": [],
                  "next": 0,
                });
                Navigator.pop(context);
                setState(() {});
              }
            },
            decoration: const InputDecoration(hintText: 'Name'),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () {
                if (formState.currentState!.validate()) {
                  widget.data['motions'].add({
                    "name": controller.text,
                    "steps": [],
                    "next": 0,
                  });
                  Navigator.pop(context);
                  setState(() {});
                }
              },
              child: Text('Save')),
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        ],
      ),
    );
  }

  void deleteMotion() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete this motion ?'),
        actions: [
          TextButton(
              onPressed: () {
                setState(() {
                  widget.data['motions'].removeAt(openedMotion);
                  openedMotion = -1;
                  openedStep = -1;
                  Navigator.pop(context);
                });
              },
              child: Text('Delete', style: TextStyle(color: Colors.red))),
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        ],
      ),
    );
  }

  void updateNameMotion() {
    var controller = TextEditingController(text: widget.data['motions'][openedMotion]['name']);
    var form = GlobalKey<FormState>();
    showDialog(
        context: context,
        builder: (c) => AlertDialog(
              title: Text('Update Name Motion'),
              content: Form(
                key: form,
                child: TextFormField(
                  autofocus: true,
                  controller: controller,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter some text';
                    }
                    return null;
                  },
                  onEditingComplete: () {
                    if (form.currentState!.validate()) {
                      setState(() {
                        widget.data['motions'][openedMotion]['name'] = controller.text;
                      });
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () {
                      if (form.currentState!.validate()) {
                        setState(() {
                          widget.data['motions'][openedMotion]['name'] = controller.text;
                        });
                        Navigator.pop(context);
                      }
                    },
                    child: Text('Save')),
                TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
              ],
            ));
  }

  Widget steps() {
    return Expanded(
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: openedMotion == -1 ? Colors.transparent : Color.fromARGB(200, 124, 191, 219),
          borderRadius: BorderRadius.circular(15),
        ),
        child: openedMotion != -1
            ? Column(
                children: [
                  Stack(
                    children: <Widget>[
                      // Stroked text as border.
                      Text(
                        'Motion Steps',
                        style: TextStyle(
                          fontSize: 20,
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 3
                            ..color = Colors.black,
                        ),
                      ),
                      // Solid text as fill.
                      Text(
                        'Motion Steps',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.grey[300],
                        ),
                      ),
                    ],
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Step', style: TextStyle(color: Colors.white)),
                      Text('Pause', style: TextStyle(color: Colors.white)),
                      Text('Time', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: widget.data['motions'][openedMotion]['steps'].length,
                      itemBuilder: (context, i) => Row(
                        children: [
                          Container(
                            height: 36,
                            width: 36,
                            margin: EdgeInsets.symmetric(vertical: 5, horizontal: 5),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Color(0XFFDADADA),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text((i).toString()),
                          ),
                          Expanded(
                            child: Material(
                              color: openedStep == i ? Color(0xff219EBC) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onDoubleTap: () async {
                                  int temp = await numEditor(widget.data['motions'][openedMotion]['steps'][i]['pause']);
                                  setState(() {
                                    widget.data['motions'][openedMotion]['steps'][i]['pause'] = temp;
                                  });
                                },
                                onTap: () {
                                  setState(() {
                                    openedStep = i;
                                  });
                                },
                                child: Container(
                                  height: 36,
                                  alignment: Alignment.center,
                                  margin: EdgeInsets.symmetric(horizontal: 5),
                                  child: Text(
                                    widget.data['motions'][openedMotion]['steps'][i]['pause'].toString(),
                                    style: TextStyle(color: openedStep == i ? Colors.white : Colors.black),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Material(
                              color: openedStep == i ? Color(0xff219EBC) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                onDoubleTap: () async {
                                  int temp = await numEditor(widget.data['motions'][openedMotion]['steps'][i]['time']);
                                  setState(() {
                                    widget.data['motions'][openedMotion]['steps'][i]['time'] = temp;
                                  });
                                },
                                onTap: () {
                                  setState(() {
                                    openedStep = i;
                                  });
                                },
                                child: Container(
                                  height: 36,
                                  alignment: Alignment.center,
                                  child: Text(
                                    widget.data['motions'][openedMotion]['steps'][i]['time'].toString(),
                                    style: TextStyle(color: openedStep == i ? Colors.white : Colors.black),
                                  ),
                                ),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Column(),
      ),
    );
  }

  Widget stepEditor() {
    return Column(
      children: [
        const SizedBox(height: 100),
        AnimatedContainer(
          duration: Duration(milliseconds: 200),
          decoration: BoxDecoration(color: openedMotion == -1 ? Colors.transparent : Color.fromARGB(200, 124, 191, 219), borderRadius: BorderRadius.circular(10)),
          padding: EdgeInsets.all(10),
          child: openedMotion != -1
              ? Column(
                  children: [
                    IconButton.filled(
                        onPressed: () {
                          List tempValue = [];
                          widget.data['servos'].forEach((val) {
                            tempValue.add(val['name'] == 'mx-28' ? 2048 : 512);
                          });
                          setState(() {
                            widget.data['motions'][openedMotion]['steps'].add({"time": 1000, "pause": 1000, "value": tempValue});
                          });
                        },
                        icon: Icon(Icons.add)),
                    const SizedBox(height: 10),
                    IconButton.filled(
                        onPressed: () {
                          if (openedStep == -1) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please open the step first!')));
                          } else {
                            setState(() {
                              widget.data['motions'][openedMotion]['steps'].removeAt(openedStep);
                              openedStep = -1;
                            });
                          }
                        },
                        icon: Icon(Icons.remove)),
                  ],
                )
              : SizedBox(width: 38.5, height: 100),
        )
      ],
    );
  }

  Widget poseOfStep() {
    return Expanded(
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: openedMotion == -1 ? Colors.transparent : Color.fromARGB(200, 124, 191, 219),
          borderRadius: BorderRadius.circular(15),
        ),
        child: openedMotion != -1 && openedStep != -1
            ? Column(
                children: [
                  Stack(
                    children: <Widget>[
                      // Stroked text as border.
                      Text(
                        'Pose of Step',
                        style: TextStyle(
                          fontSize: 20,
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 3
                            ..color = Colors.black,
                        ),
                      ),
                      // Solid text as fill.
                      Text(
                        'Pose of Step',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.grey[300],
                        ),
                      ),
                    ],
                  ),
                  const Row(
                    children: [
                      Text('ID', style: TextStyle(color: Colors.white)),
                      const SizedBox(width: 50),
                      Text('Value', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  Expanded(
                      child: ListView.builder(
                    itemCount: widget.data['motions'][openedMotion]['steps'][openedStep]['value'].length,
                    itemBuilder: (c, index) => Row(
                      children: [
                        Container(
                          height: 36,
                          width: 36,
                          margin: EdgeInsets.symmetric(vertical: 5, horizontal: 5),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Color(0XFFDADADA),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(widget.data['servos'][index]['id'].toString()),
                        ),
                        Expanded(
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              onDoubleTap: () async {
                                int temp = await numEditor(widget.data['motions'][openedMotion]['steps'][openedStep]['value'][index]);
                                setState(() {
                                  widget.data['motions'][openedMotion]['steps'][openedStep]['value'][index] = temp;
                                });
                              },
                              child: Container(
                                height: 36,
                                alignment: Alignment.center,
                                child: Text(widget.data['motions'][openedMotion]['steps'][openedStep]['value'][index].toString()),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ))
                ],
              )
            : Column(),
      ),
    );
  }

  Widget poseOfRobot() {
    return Expanded(
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: port == "" ? Colors.transparent : Color.fromARGB(200, 124, 191, 219),
          borderRadius: BorderRadius.circular(15),
        ),
        child: port != ""
            ? Column(
                children: [
                  Stack(
                    children: <Widget>[
                      // Stroked text as border.
                      Text(
                        'Pose of Robot',
                        style: TextStyle(
                          fontSize: 20,
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 3
                            ..color = Colors.black,
                        ),
                      ),
                      // Solid text as fill.
                      Text(
                        'Pose of Robot',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.grey[300],
                        ),
                      ),
                    ],
                  ),
                  const Row(
                    children: [
                      Text('ID', style: TextStyle(color: Colors.white)),
                      const SizedBox(width: 50),
                      Text('Value', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  Expanded(
                      child: ListView.builder(
                    itemCount: servos.length,
                    itemBuilder: (c, index) => Row(
                      children: [
                        Container(
                          height: 36,
                          width: 36,
                          margin: EdgeInsets.symmetric(vertical: 5, horizontal: 5),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Color(0XFFDADADA),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(servos[index]['id'].toString()),
                        ),
                        Expanded(
                          child: Material(
                            color: selectedServo[index]['selected'] ? Color(0xff219EBC) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              // onDoubleTap: () async {
                              //   int temp = await numEditor(servos[index]['pos']);
                              //   setState(() {
                              //     widget.data['motions'][openedMotion]['steps'][openedStep]['value'][index] = temp;
                              //   });
                              // },

                              onTap: () {
                                setState(() {
                                  selectedServo[index]['selected'] = !selectedServo[index]['selected'];
                                });
                              },

                              child: Container(
                                height: 36,
                                alignment: Alignment.center,
                                child: Text(
                                  servos[index]['state'] == false ? 'OFF' : servos[index]['pos'].toString(),
                                  style: TextStyle(color: selectedServo[index]['selected'] ? Colors.white : Colors.black),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ))
                ],
              )
            : Column(),
      ),
    );
  }

  Widget sendAndGetWidget() {
    return Column(
      children: [
        const SizedBox(height: 100),
        AnimatedContainer(
          duration: Duration(milliseconds: 200),
          decoration: BoxDecoration(color: port == "" ? Colors.transparent : Color.fromARGB(200, 124, 191, 219), borderRadius: BorderRadius.circular(10)),
          padding: EdgeInsets.all(10),
          child: port != ""
              ? Column(
                  children: [
                    IconButton.filled(
                        onPressed: () {
                          if (port == "") {
                            connectDevices();
                          } else {
                            String temp = "W";
                            for (int i = 0; i < widget.data['servos'].length; i++) {
                              temp += "${widget.data['servos'][i]['id']},${widget.data['motions'][openedMotion]['steps'][openedStep]['value'][i]},";
                            }
                            send(temp);

                            for (int i = 0; i < widget.data['servos'].length; i++) {
                              for (int j = 0; j < servos.length; j++) {
                                if (widget.data['servos'][i]['id'] == servos[j]['id']) {
                                  servos[j]['pos'] = widget.data['motions'][openedMotion]['steps'][openedStep]['value'][i];
                                  servos[j]['state'] = true;
                                  break;
                                }
                              }
                            }
                            setState(() {});
                          }
                        },
                        icon: Icon(Icons.navigate_next)),
                    const SizedBox(height: 10),
                    IconButton.filled(
                        onPressed: () {
                          if (port == "") {
                            connectDevices();
                          } else {
                            for (int i = 0; i < widget.data['servos'].length; i++) {
                              for (int j = 0; j < servos.length; j++) {
                                if (widget.data['servos'][i]['id'] == servos[j]['id']) {
                                  widget.data['motions'][openedMotion]['steps'][openedStep]['value'][i] = servos[j]['pos'];
                                  break;
                                }
                              }
                            }
                            setState(() {});
                          }
                        },
                        icon: Icon(Icons.navigate_before)),
                  ],
                )
              : SizedBox(width: 38.5, height: 100),
        )
      ],
    );
  }

  Future<int> numEditor(before) async {
    var controller = TextEditingController(text: before.toString());
    var form = GlobalKey<FormState>();
    int after = before;
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        content: Form(
            key: form,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              onEditingComplete: () {
                after = int.parse(controller.text);
                Navigator.pop(context);
              },
            )),
        actions: [
          TextButton(
              onPressed: () {
                after = int.parse(controller.text);
                Navigator.pop(context);
              },
              child: Text('Save')),
          TextButton(
              onPressed: () {
                after = before;
                Navigator.pop(context);
              },
              child: Text('Cancel')),
        ],
      ),
    );
    return after;
  }
}
