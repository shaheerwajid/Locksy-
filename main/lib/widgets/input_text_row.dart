import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../providers/ChatProvider.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import 'cronometro.dart';

class ChatInputRow extends StatefulWidget {
  final ChatProvider p;
  final ChatService c;
  final AuthService a;

  const ChatInputRow({
    Key? key,
    required this.p,
    required this.c,
    required this.a,
  }) : super(key: key);

  @override
  _ChatInputRowState createState() => _ChatInputRowState();
}

class _ChatInputRowState extends State<ChatInputRow>
    with AutomaticKeepAliveClientMixin {
  bool _emojiShowing = false;
  bool _attachmentShowing = false;
  late FocusNode _focusNode;
  bool _wasFocused = false; // Track if text field had focus before rebuild

  @override
  bool get wantKeepAlive => true; // Keep the widget alive to preserve focus

  @override
  void initState() {
    super.initState();
    _focusNode = widget.p.focusNode;
    _wasFocused = _focusNode.hasFocus;

    // Listener to close emoji picker when focus goes back to the text field
    _focusNode.addListener(_onFocusChange);

    // Ensure focus is maintained after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _wasFocused && !_focusNode.hasFocus) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(ChatInputRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Preserve focus state after rebuild - only restore if it was intentionally focused
    // Don't restore if user manually unfocused
    if (_wasFocused && !_focusNode.hasFocus && mounted) {
      // Restore focus if it was focused before rebuild
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _wasFocused && !_focusNode.hasFocus) {
          _focusNode.requestFocus();
        }
      });
    }
    // Update the focus state tracking
    _wasFocused = _focusNode.hasFocus;
  }

  void _onFocusChange() {
    // Check if widget is still mounted before calling setState
    if (!mounted) return;

    _wasFocused = _focusNode.hasFocus;

    if (_focusNode.hasFocus) {
      setState(() {
        _attachmentShowing = false;
        _emojiShowing = false; // Close emoji picker when focus is on text field
      });
    }
  }

  @override
  void dispose() {
    // CRITICAL: Remove listener to prevent setState() after dispose
    _focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  // Method to handle adding emojis to the TextField
  void onEmojiSelected(Emoji emoji) {
    widget.p.textController.text +=
        emoji.emoji; // Add selected emoji to the text field
    widget.p.textController.selection = TextSelection.fromPosition(
        TextPosition(offset: widget.p.textController.text.length));

    // CRITICAL: Update typing state when emoji is added via picker
    // This ensures send button appears and typing indicator is sent
    if (widget.p.textController.text.trim().isNotEmpty) {
      widget.p.onchangeTextfield(
        widget.p.textController.text,
        widget.a.usuario!,
        widget.c.usuarioPara!,
      );
    }

    // Force rebuild to show send button if text is present
    setState(() {});
  }

  // Build the send/record button based on current state
  Widget _buildSendButton() {
    // CRITICAL: Check both estaEscribiendo AND if text controller has content
    // This ensures send button appears when using emoji picker (which doesn't trigger onChanged)
    final hasText = widget.p.textController.text.trim().isNotEmpty;
    final shouldShowSendButton =
        widget.p.estaEscribiendo || widget.p.filePath != null || hasText;

    if (!shouldShowSendButton && widget.p.filePath == null) {
      // Show mic button when no text and not recording
      return GestureDetector(
        onTap: () {
          widget.p.isRecording
              ? widget.p.stopRecording(widget.a, widget.c)
              : widget.p.startRecording();
        },
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Colors.blue, // Adjust as needed
            borderRadius: BorderRadius.circular(30),
          ),
          height: 38,
          width: 38,
          alignment: Alignment.center,
          child: Icon(
            !widget.p.isRecording ? Icons.mic : Icons.send,
            color: Colors.white, // Adjust as needed
            size: 20,
          ),
        ),
      );
    } else {
      // Show send button when there's text or file
      return GestureDetector(
        onTap: () => shouldShowSendButton
            ? widget.p.handleSubmit(
                widget.p.textController.text.trim(),
                widget.a.usuario!,
                widget.c.usuarioPara!,
                widget.a,
                widget.c,
                context)
            : null,
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.blue, // Adjust as needed
            borderRadius: BorderRadius.circular(30),
          ),
          height: 38,
          width: 38,
          alignment: Alignment.center,
          child: const Icon(
            Icons.send,
            color: Colors.white, // Adjust as needed
            size: 20,
          ),
        ),
      );
    }
  }

  // Method to handle attachment button clicks
  void onAttachmentSelected(int action) {
    switch (action) {
      case 1:
        widget.p.takePhoto(widget.a, widget.c);
        break;
      case 2:
        widget.p.takeVideo(widget.a, widget.c);
        break;
      case 3:
        widget.p.selectGalleryImage(widget.a, widget.c);
        break;
      case 4:
        widget.p.selectDocument(widget.a, widget.c);
        break;
      case 5:
        widget.p.selectAudio(widget.a, widget.c);
        break;
      case 6:
        widget.p.selectDocument(widget.a, widget.c);
        break;
    }
    setState(() {
      _attachmentShowing = false; // Hide attachment options after selection
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              !widget.p.isRecording
                  ? const SizedBox()
                  : GestureDetector(
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.red, // Adjust as needed
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white, // Adjust as needed
                          size: 30,
                        ),
                      ),
                      onTap: () {
                        widget.p.cancelRecording();
                      },
                    ),
              const SizedBox(width: 10),

              // The TextField with emoji picker integrated
              Flexible(
                child: SizedBox(
                    height: 44,
                    child: widget.p.isRecording
                        ? const Cronometro()
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.grey
                                  .shade300, // Greyish color for background
                              borderRadius:
                                  BorderRadius.circular(30), // Rounded corners
                            ),
                            child: TextField(
                              key: const ValueKey(
                                  'chat_input_field'), // Key to maintain identity across rebuilds
                              textInputAction: TextInputAction.send,
                              keyboardType: TextInputType.multiline,
                              minLines: 1,
                              maxLines: 5,
                              style: const TextStyle(
                                fontWeight: FontWeight.normal,
                                color: Colors.black, // Text color
                                fontSize: 15,
                              ),
                              controller: widget.p.textController,
                              onSubmitted: (texto) {
                                widget.c.usuarioPara!.printUsuario();
                                widget.p.handleSubmit(
                                    texto,
                                    widget.a.usuario!,
                                    widget.c.usuarioPara!,
                                    widget.a,
                                    widget.c,
                                    context);
                              },
                              onChanged: (texto) {
                                widget.p.onchangeTextfield(texto,
                                    widget.a.usuario!, widget.c.usuarioPara!);
                              },
                              decoration: InputDecoration(
                                prefixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _emojiShowing =
                                          !_emojiShowing; // Toggle emoji visibility
                                      if (_emojiShowing) {
                                        _attachmentShowing =
                                            false; // Hide attachment options
                                        FocusScope.of(context)
                                            .unfocus(); // Close the keyboard
                                      } else {
                                        FocusScope.of(context).requestFocus(
                                            _focusNode); // Focus back on the text field
                                      }
                                    });
                                  },
                                  icon: Icon(
                                    !_emojiShowing
                                        ? FontAwesomeIcons.faceSmile
                                        : Icons.keyboard,
                                    color: Colors.black, // Icon color
                                  ),
                                ),
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _attachmentShowing =
                                          !_attachmentShowing; // Toggle attachment visibility
                                      _emojiShowing =
                                          false; // Hide emoji picker
                                      if (_attachmentShowing) {
                                        FocusScope.of(context)
                                            .unfocus(); // Close the keyboard
                                      } else {
                                        FocusScope.of(context).requestFocus(
                                            _focusNode); // Focus back on the text field
                                      }
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.attach_file,
                                    color: Colors.black, // Icon color
                                  ),
                                ),
                                hintText: 'Send Message',
                                hintStyle: const TextStyle(
                                  fontFamily: 'Roboto-Regular',
                                  letterSpacing: 1.0,
                                  fontWeight: FontWeight.normal,
                                  color: Colors.grey, // Hint text color
                                  fontSize: 15,
                                ),
                                border: InputBorder.none, // Remove the border
                              ),
                              focusNode: _focusNode,
                            ),
                          )),
              ),
              const SizedBox(width: 10),

              // Recording or send button
              // CRITICAL: Check both estaEscribiendo AND if text controller has content
              // This ensures send button appears when using emoji picker (which doesn't trigger onChanged)
              _buildSendButton(),
            ],
          ),
          if (_attachmentShowing)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: SizedBox(
                height: 250,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4, // 3 columns in the grid
                    crossAxisSpacing: 20, // Space between columns
                    mainAxisSpacing: 10, // Space between rows
                  ),
                  itemCount: 5, // Number of attachment options
                  itemBuilder: (context, index) {
                    // Define the options
                    List<Map<String, dynamic>> attachmentOptions = [
                      {
                        'icon': Icons.camera_alt,
                        'label': "Picture",
                        'action': 1
                      },
                      {
                        'icon': Icons.video_camera_back,
                        'label': "Video",
                        'action': 2
                      },
                      {'icon': Icons.photo, 'label': "Gallery", 'action': 3},
                      {
                        'icon': Icons.insert_drive_file,
                        'label': "Document",
                        'action': 4
                      },
                      {'icon': Icons.audio_file, 'label': "Audio", 'action': 5},
                    ];

                    var option = attachmentOptions[index];

                    return GestureDetector(
                      onTap: () => onAttachmentSelected(option['action']),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.grey.shade200,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(option['icon'], size: 40, color: Colors.black),
                            const SizedBox(height: 5),
                            Text(
                              option['label'],
                              style: const TextStyle(color: Colors.black),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // Emoji picker section (below the Row)
          if (_emojiShowing)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) {
                  onEmojiSelected(emoji);
                },
              ),
            ),
        ],
      ),
    );
  }

  // Widget _attachmentOption(IconData icon, String label, int action) {
  //   return GestureDetector(
  //     onTap: () => onAttachmentSelected(action),
  //     child: Container(
  //       padding: const EdgeInsets.all(15),
  //       decoration: BoxDecoration(
  //         border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
  //       ),
  //       child: Row(
  //         children: [
  //           Icon(icon, size: 24, color: Colors.black),
  //           const SizedBox(width: 10),
  //           Text(
  //             label,
  //             style: const TextStyle(color: Colors.black),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }
}
