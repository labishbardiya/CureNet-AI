import os
import re

dir_path = "lib/screens"

new_button = """  Widget _scanButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (ModalRoute.of(context)?.settings.name != '/doc-scan') {
          Navigator.pushNamed(context, '/doc-scan');
        }
      },
      child: Transform.translate(
        offset: const Offset(0, -24),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF00A3A3), Color(0xFF00C4C4)]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00A3A3).withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.camera_alt, size: 28, color: Colors.white),
          ),
        ),
      ),
    );
  }"""

for filename in os.listdir(dir_path):
    if filename.endswith(".dart"):
        file_path = os.path.join(dir_path, filename)
        with open(file_path, "r") as f:
            content = f.read()

        # Find Widget _scanButton(BuildContext context)
        # We need to match from `Widget _scanButton` up to the closing brace of the method.
        # It's always at the end of the class.
        
        pattern = r'Widget _scanButton\(BuildContext context\) \{.*?\n  \}'
        
        if re.search(pattern, content, re.DOTALL):
            new_content = re.sub(pattern, new_button, content, flags=re.DOTALL)
            with open(file_path, "w") as f:
                f.write(new_content)
            print(f"Updated {filename}")

