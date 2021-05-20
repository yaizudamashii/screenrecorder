import 'dart:io';

import 'package:flutter/material.dart';
import 'package:screen_recorder/screen_recorder.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  ScreenRecorderController controller = ScreenRecorderController();

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'You have pushed the button this many times:',
            ),
            ScreenRecorder(
              controller: controller,
              child: Container(
                height: 100,
                width: 100,
                color: Colors.white,
                child: Center(
                  child: Text(
                    '$_counter',
                    style: Theme.of(context).textTheme.headline4,
                  ),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Directory tempDir = await getTemporaryDirectory();
                controller.tempDir = tempDir;
                controller.start();
              },
              child: Text('Start'),
            ),
            ElevatedButton(
              onPressed: () {
                controller.stop();
              },
              child: Text('Stop'),
            ),
            ElevatedButton(
              onPressed: () async {
                var gif = await controller.export();
                showDialog(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      content: Image.memory(gif),
                    );
                  },
                );
              },
              child: Text('show recoded video'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ),
    );
  }
}
