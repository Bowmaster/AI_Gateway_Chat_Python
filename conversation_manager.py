"""
conversation_manager.py - Conversation persistence and resume functionality

Manages saving, loading, and listing conversations from ~/.conversations/
"""

import json
import re
from datetime import datetime
from pathlib import Path
from typing import Optional, List, Dict


class ConversationManager:
    """Manages conversation persistence to disk."""

    def __init__(self, storage_dir: Optional[Path] = None):
        """
        Initialize the conversation manager.

        Args:
            storage_dir: Directory to store conversations. Defaults to ~/.conversations/
        """
        self.storage_dir = storage_dir or Path.home() / ".conversations"
        self.storage_dir.mkdir(parents=True, exist_ok=True)
        self.index_path = self.storage_dir / "index.json"

    def _slugify(self, title: str) -> str:
        """
        Convert a title to a valid filename/ID.

        Args:
            title: The conversation title

        Returns:
            A slugified version suitable for filenames
        """
        # Convert to lowercase and replace spaces with hyphens
        slug = title.lower().strip()
        # Replace non-alphanumeric characters (except hyphens) with hyphens
        slug = re.sub(r"[^a-z0-9\-]", "-", slug)
        # Collapse multiple hyphens into one
        slug = re.sub(r"-+", "-", slug)
        # Remove leading/trailing hyphens
        slug = slug.strip("-")
        # Limit length
        if len(slug) > 50:
            slug = slug[:50].rstrip("-")
        return slug or "conversation"

    def _get_conversation_path(self, conv_id: str) -> Path:
        """Get the file path for a conversation ID."""
        return self.storage_dir / f"{conv_id}.json"

    def _load_index(self) -> Dict:
        """Load the index file."""
        if self.index_path.exists():
            try:
                with open(self.index_path, "r", encoding="utf-8") as f:
                    return json.load(f)
            except (json.JSONDecodeError, IOError):
                pass
        return {"conversations": []}

    def _save_index(self, index: Dict):
        """Save the index file."""
        with open(self.index_path, "w", encoding="utf-8") as f:
            json.dump(index, f, indent=2)

    def _update_index(self, conv_id: str, title: str, message_count: int, preview: str):
        """Update or add an entry in the index."""
        index = self._load_index()
        now = datetime.now().isoformat()

        # Find existing entry
        existing = None
        for entry in index["conversations"]:
            if entry["id"] == conv_id:
                existing = entry
                break

        if existing:
            existing["title"] = title
            existing["updated_at"] = now
            existing["message_count"] = message_count
            existing["preview"] = preview[:100] if preview else ""
        else:
            index["conversations"].append({
                "id": conv_id,
                "title": title,
                "created_at": now,
                "updated_at": now,
                "message_count": message_count,
                "preview": preview[:100] if preview else ""
            })

        self._save_index(index)

    def _remove_from_index(self, conv_id: str):
        """Remove an entry from the index."""
        index = self._load_index()
        index["conversations"] = [
            entry for entry in index["conversations"]
            if entry["id"] != conv_id
        ]
        self._save_index(index)

    def save(
        self,
        messages: List[Dict[str, str]],
        title: str,
        conv_id: Optional[str] = None,
        system_prompt: Optional[str] = None,
        working_directory: Optional[str] = None,
        model_key: Optional[str] = None,
    ) -> str:
        """
        Save a conversation to disk.

        Args:
            messages: List of message dictionaries
            title: Conversation title
            conv_id: Optional existing conversation ID (for updates)
            system_prompt: Optional system prompt
            working_directory: Optional working directory path
            model_key: Optional model key

        Returns:
            The conversation ID
        """
        # Generate ID from title if not provided
        if not conv_id:
            conv_id = self._slugify(title)
            # Handle duplicates by appending a number
            base_id = conv_id
            counter = 1
            while self._get_conversation_path(conv_id).exists():
                conv_id = f"{base_id}-{counter}"
                counter += 1

        now = datetime.now().isoformat()
        conv_path = self._get_conversation_path(conv_id)

        # Load existing data to preserve created_at
        created_at = now
        if conv_path.exists():
            try:
                with open(conv_path, "r", encoding="utf-8") as f:
                    existing = json.load(f)
                    created_at = existing.get("created_at", now)
            except (json.JSONDecodeError, IOError):
                pass

        # Get preview from first user message
        preview = ""
        for msg in messages:
            if msg.get("role") == "user":
                preview = msg.get("content", "")[:100]
                break

        conversation = {
            "id": conv_id,
            "title": title,
            "created_at": created_at,
            "updated_at": now,
            "model_key": model_key,
            "system_prompt": system_prompt,
            "working_directory": working_directory,
            "message_count": len(messages),
            "messages": messages,
        }

        # Save conversation file
        with open(conv_path, "w", encoding="utf-8") as f:
            json.dump(conversation, f, indent=2)

        # Update index
        self._update_index(conv_id, title, len(messages), preview)

        return conv_id

    def load(self, conv_id: str) -> Optional[Dict]:
        """
        Load a conversation by ID.

        Args:
            conv_id: The conversation ID

        Returns:
            The conversation dictionary or None if not found
        """
        conv_path = self._get_conversation_path(conv_id)
        if not conv_path.exists():
            return None

        try:
            with open(conv_path, "r", encoding="utf-8") as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            return None

    def list_all(self) -> List[Dict]:
        """
        Return list of conversation summaries.

        Returns:
            List of conversation summary dictionaries, sorted by updated_at (newest first)
        """
        index = self._load_index()
        conversations = index.get("conversations", [])

        # Sort by updated_at (newest first)
        conversations.sort(
            key=lambda x: x.get("updated_at", ""),
            reverse=True
        )

        return conversations

    def delete(self, conv_id: str) -> bool:
        """
        Delete a conversation.

        Args:
            conv_id: The conversation ID

        Returns:
            True if deleted, False if not found
        """
        conv_path = self._get_conversation_path(conv_id)

        if not conv_path.exists():
            return False

        try:
            conv_path.unlink()
            self._remove_from_index(conv_id)
            return True
        except IOError:
            return False

    def get_by_number(self, number: int) -> Optional[Dict]:
        """
        Get a conversation by its number in the list (1-indexed).

        Args:
            number: The conversation number (1-indexed)

        Returns:
            The conversation dictionary or None if not found
        """
        conversations = self.list_all()
        if 1 <= number <= len(conversations):
            conv_id = conversations[number - 1]["id"]
            return self.load(conv_id)
        return None

    def rebuild_index(self):
        """Rebuild the index from conversation files."""
        index = {"conversations": []}

        for conv_path in self.storage_dir.glob("*.json"):
            if conv_path.name == "index.json":
                continue

            try:
                with open(conv_path, "r", encoding="utf-8") as f:
                    conv = json.load(f)

                # Get preview from first user message
                preview = ""
                for msg in conv.get("messages", []):
                    if msg.get("role") == "user":
                        preview = msg.get("content", "")[:100]
                        break

                index["conversations"].append({
                    "id": conv.get("id", conv_path.stem),
                    "title": conv.get("title", conv_path.stem),
                    "created_at": conv.get("created_at", ""),
                    "updated_at": conv.get("updated_at", ""),
                    "message_count": len(conv.get("messages", [])),
                    "preview": preview,
                })
            except (json.JSONDecodeError, IOError):
                continue

        self._save_index(index)
