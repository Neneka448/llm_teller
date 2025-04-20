import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 导入 SharedPreferences

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Controllers for text fields
  final _apiHostController = TextEditingController(text: 'https://openrouter.ai/api/v1'); // Default OpenRouter host
  final _apiPathController = TextEditingController(text: '/chat/completions'); // Default path
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController(text: 'gpt-4o'); // Default model from image
  // Controller for custom max messages
  final _customMaxMessagesController = TextEditingController();

  // State variables for sliders and switch
  bool _improveNetwork = false;
  // Use int? for maxMessages, null means unlimited
  int? _maxMessages = 20;
  double _temperature = 0.7;
  double _topP = 1.0;
  bool _obscureApiKey = true;
  bool _streamOutput = true; // Add state variable for streaming (default true)

  // Track which option is selected for Max Messages
  // Can be one of the predefined values, null (for unlimited), or -1 (for custom)
  int? _selectedMaxMessageOption = 20;

  // Predefined message count options
  final List<int> _predefinedMaxMessages = [10, 20, 30, 50, 100, 200, 500, 1000];

  @override
  void initState() {
    super.initState();
    _loadSettings(); // 在初始化时加载设置
    // Initialize custom text field if initial value requires it
    if (_selectedMaxMessageOption == -1) {
      _customMaxMessagesController.text = _maxMessages?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _apiHostController.dispose();
    _apiPathController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _customMaxMessagesController.dispose(); // Dispose the new controller
    super.dispose();
  }

  // --- Load Settings Method ---
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final loadedMaxMessages = prefs.getInt('maxMessages'); // Load into temp var
    print('--- Loading Settings ---'); // DEBUG
    print('Loaded maxMessages from prefs: $loadedMaxMessages'); // DEBUG

    setState(() {
      _apiHostController.text = prefs.getString('apiHost') ?? 'https://openrouter.ai/api/v1';
      _apiPathController.text = prefs.getString('apiPath') ?? '/chat/completions';
      _apiKeyController.text = prefs.getString('apiKey') ?? '';
      _modelController.text = prefs.getString('model') ?? 'gpt-4o';
      _improveNetwork = prefs.getBool('improveNetwork') ?? false;
      _temperature = prefs.getDouble('temperature') ?? 0.7;
      _topP = prefs.getDouble('topP') ?? 1.0;
      _streamOutput = prefs.getBool('streamOutput') ?? true; // Load stream setting

      // Assign loaded value to state variable
      _maxMessages = loadedMaxMessages;

      // Determine the selected option based on the loaded _maxMessages
       print('Determining selected option based on loaded _maxMessages: $_maxMessages'); // DEBUG
       if (_maxMessages == null) {
         _selectedMaxMessageOption = null; // Unlimited
         print('Selected option set to: null (Unlimited)'); // DEBUG
       } else if (_predefinedMaxMessages.contains(_maxMessages)) {
         _selectedMaxMessageOption = _maxMessages;
         print('Selected option set to: $_maxMessages (Predefined)'); // DEBUG
       } else {
         _selectedMaxMessageOption = -1; // Custom
         _customMaxMessagesController.text = _maxMessages.toString();
         print('Selected option set to: -1 (Custom), value: $_maxMessages'); // DEBUG
       }

      // NOTE: API Key obscuring state is not saved, it's just UI state
    });
  }

  // --- Save Settings Method ---
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    print('--- Saving Settings ---'); // DEBUG
    await prefs.setString('apiHost', _apiHostController.text);
    await prefs.setString('apiPath', _apiPathController.text);
    await prefs.setString('apiKey', _apiKeyController.text);
    await prefs.setString('model', _modelController.text);
    await prefs.setBool('improveNetwork', _improveNetwork);

    // Handle saving maxMessages (null for unlimited)
     print('Saving maxMessages value: $_maxMessages'); // DEBUG
     if (_maxMessages == null) {
       await prefs.remove('maxMessages'); // Or setInt('maxMessages', some_special_value) if null is not allowed
     } else {
       await prefs.setInt('maxMessages', _maxMessages!); // Save the integer value
     }

    await prefs.setDouble('temperature', _temperature);
    await prefs.setDouble('topP', _topP);
    await prefs.setBool('streamOutput', _streamOutput); // Save stream setting
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        elevation: 1.0,
        backgroundColor: Colors.white, // Consistent background
         foregroundColor: Colors.black87,
         iconTheme: IconThemeData(color: Colors.black87), // Back button color
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch elements horizontally
          children: <Widget>[
            _buildTextField('API Host', _apiHostController),
            SizedBox(height: 16.0),
            _buildTextField('API Path', _apiPathController),
            SizedBox(height: 16.0),
            SwitchListTile(
              title: Text('Improve Network Compatibility'),
              secondary: Icon(Icons.help_outline, color: Colors.grey.shade600),
              value: _improveNetwork,
              onChanged: (bool value) {
                setState(() {
                  _improveNetwork = value;
                });
              },
               contentPadding: EdgeInsets.zero, // Remove default padding
            ),
            SizedBox(height: 16.0),
            _buildTextField(
              'API Key',
              _apiKeyController,
              obscureText: _obscureApiKey,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureApiKey ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey.shade600,
                ),
                onPressed: () {
                  setState(() {
                    _obscureApiKey = !_obscureApiKey;
                  });
                },
              ),
            ),
            SizedBox(height: 16.0),
             _buildTextField('Model', _modelController),
             SizedBox(height: 24.0),

            // --- Stream Output Switch ---
             SwitchListTile(
               title: Text('流式输出 (Stream Output)'),
               value: _streamOutput,
               onChanged: (bool value) {
                 setState(() {
                   _streamOutput = value;
                 });
               },
               contentPadding: EdgeInsets.zero,
             ),
              SizedBox(height: 16.0),

            // --- Max Message Count Section ---
            Text('Max Message Count in Context', style: TextStyle(fontSize: 16.0)),
            SizedBox(height: 8.0),
            Wrap(
              spacing: 8.0, // Horizontal space between chips
              runSpacing: 4.0, // Vertical space between lines
              children: [
                // Predefined options
                ..._predefinedMaxMessages.map((count) {
                  return ChoiceChip(
                    label: Text(count.toString()),
                    selected: _selectedMaxMessageOption == count,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedMaxMessageOption = count;
                          _maxMessages = count;
                           // Clear custom field if a predefined option is selected
                          _customMaxMessagesController.clear();
                        });
                      }
                    },
                  );
                }).toList(),
                // Unlimited option
                ChoiceChip(
                  label: Text('Unlimited'),
                  selected: _selectedMaxMessageOption == null,
                  onSelected: (selected) {
                     if (selected) {
                       setState(() {
                         _selectedMaxMessageOption = null;
                         _maxMessages = null;
                         _customMaxMessagesController.clear();
                       });
                     }
                  },
                ),
                // Custom option
                ChoiceChip(
                  label: Text('Custom'),
                  selected: _selectedMaxMessageOption == -1,
                  onSelected: (selected) {
                     if (selected) {
                       setState(() {
                         _selectedMaxMessageOption = -1;
                         // Try parsing existing custom text, else null
                         _maxMessages = int.tryParse(_customMaxMessagesController.text);
                       });
                     }
                  },
                ),
              ],
            ),
            // Show TextField only if Custom is selected
            if (_selectedMaxMessageOption == -1)
              Padding(
                 padding: const EdgeInsets.only(top: 8.0),
                 child: TextField(
                    controller: _customMaxMessagesController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Enter custom count',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
                    ),
                    onChanged: (value) {
                       // Update the actual maxMessages state as user types
                      setState(() {
                        _maxMessages = int.tryParse(value);
                      });
                    },
                 ),
              ),
            SizedBox(height: 16.0),
            // --- End Max Message Count Section ---

            _buildSlider('Temperature', _temperature, 0, 2, _temperature.toStringAsFixed(2), (value) {
              setState(() {
                _temperature = value;
              });
            }),
             SizedBox(height: 16.0),
             _buildSlider('Top P', _topP, 0, 1, _topP.toStringAsFixed(1), (value) {
              setState(() {
                _topP = value;
              });
            }),
            SizedBox(height: 32.0),
            ElevatedButton(
              onPressed: () async { // Make onPressed async
                 await _saveSettings(); // Call save method
                 // Show feedback
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Settings Saved')), // Updated message
                );
                Navigator.pop(context); // Go back after saving
              },
              child: Text('SAVE'),
               style: ElevatedButton.styleFrom(
                 padding: EdgeInsets.symmetric(vertical: 12.0),
               ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for creating text fields with labels
  Widget _buildTextField(String label, TextEditingController controller, {bool obscureText = false, Widget? suffixIcon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        SizedBox(height: 4.0),
        TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
             suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }

   // Helper widget for creating sliders with labels and value display
  Widget _buildSlider(String label, double value, double min, double max, String valueLabel, Function(double) onChanged) {
    // 根据不同的滑块设置不同的分割数
    int divisions;
    if (label == 'Max Message Count in Context') {
      divisions = max.toInt() - min.toInt();
    } else if (label == 'Temperature') {
      divisions = 20; // 温度从0到2，分成20份，每步0.1
    } else {
      divisions = 10; // 其他滑块使用默认值
    }

    return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                 Text(label, style: TextStyle(fontSize: 16.0)),
                Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Text(valueLabel),
                ),
            ]
         ),
         Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions > 0 ? divisions : null, // Divisions must be > 0
            label: valueLabel,
            onChanged: onChanged,
        ),
      ]
    );
  }


}