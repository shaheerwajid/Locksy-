import 'package:flutter/material.dart';

class MessageTextField extends StatefulWidget {
  final TextEditingController textController;
  final FocusNode focusNode;
  final Function(String) onSubmitMessage;

  const MessageTextField({
    Key? key,
    required this.textController,
    required this.focusNode,
    required this.onSubmitMessage,
  }) : super(key: key);

  @override
  State<MessageTextField> createState() => _MessageTextFieldState();
}

class _MessageTextFieldState extends State<MessageTextField> {
  bool _emojiShowing = false;
  bool _attachmentShowing = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      if (widget.focusNode.hasFocus) {
        setState(() {
          _emojiShowing = false;
          _attachmentShowing = false;
        });
      }
    });
  }

  void _toggleEmojiPicker() {
    setState(() {
      _emojiShowing = !_emojiShowing;
      if (_emojiShowing) {
        _attachmentShowing = false;
        FocusScope.of(context).unfocus();
      } else {
        FocusScope.of(context).requestFocus(widget.focusNode);
      }
    });
  }

  void _toggleAttachmentOptions() {
    setState(() {
      _attachmentShowing = !_attachmentShowing;
      _emojiShowing = false;
      if (_attachmentShowing) {
        FocusScope.of(context).unfocus();
      } else {
        FocusScope.of(context).requestFocus(widget.focusNode);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade300, // Greyish color for background
            borderRadius: BorderRadius.circular(30), // Rounded corners
          ),
          child: TextField(
            textInputAction: TextInputAction.send,
            keyboardType: TextInputType.multiline,
            minLines: 1,
            maxLines: 5,
            style: const TextStyle(
              fontWeight: FontWeight.normal,
              color: Colors.black, // Text color
              fontSize: 15,
            ),
            controller: widget.textController,
            focusNode: widget.focusNode,
            onSubmitted: widget.onSubmitMessage,
            decoration: InputDecoration(
              prefixIcon: IconButton(
                onPressed: _toggleEmojiPicker,
                icon: Icon(
                  !_emojiShowing
                      ? Icons.sentiment_very_satisfied
                      : Icons.keyboard,
                  color: Colors.black, // Icon color
                ),
              ),
              suffixIcon: IconButton(
                onPressed: _toggleAttachmentOptions,
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
          ),
        ),
        if (_emojiShowing)
          const SizedBox(
            height: 250,
            child: Center(
              child: Text(
                  'Emoji Picker Placeholder'), // Replace with actual picker
            ),
          ),
        if (_attachmentShowing)
          const SizedBox(
            height: 100,
            child: Center(
              child: Text(
                  'Attachment Options Placeholder'), // Replace with actual options
            ),
          ),
      ],
    );
  }
}
