# Document Block Type

This directory contains all components related to the Document block type.

## Structure

```
document/
├── pages/                      # Document-specific pages
│   ├── document_detail_page.dart   # Document detail/view page
│   └── document_edit_page.dart     # Document creation/edit page
├── widgets/                    # Document-specific widgets
│   ├── document_card.dart          # Document card for list views
│   └── document_simple.dart        # Simplified document card
├── document_type_handler.dart  # Type handler for BlockRegistry
└── README.md                   # This file
```

## Type ID

The Document block type uses the following model ID:
- **Model ID**: `93b133932057a254cc15d0f09c91ca98`
- **Type**: `document`

This ID is defined in `lib/blocks/common/block_type_ids.dart` as `BlockTypeIds.document`.

## Components

### DocumentDetailPage

The detail page for viewing and editing document content inline. Features:
- Inline title and content editing
- Auto-save on changes
- Link count badge
- Pull-to-refresh to view full block details

### DocumentEditPage

The dedicated edit page for creating or editing documents. Features:
- Title and content fields
- Optional timestamp field
- Integration with basic block editor
- Form validation

### DocumentCard

The card component used in list views. Displays:
- Document icon
- Title (if available)
- Content preview (3 lines max)
- BID and creation date

### DocumentSimple

A simplified card component with a chat-bubble style design. Used in:
- Trace record pages
- Compact list views

## Type Handler

The `DocumentTypeHandler` implements the `BlockTypeHandler` interface and is registered with the `BlockRegistry` in `main.dart`. It provides:
- Detail page creation
- Edit page creation
- Card component creation

## Usage

### Opening a Document Detail Page

```dart
// Using BlockRegistry (recommended)
BlockRegistry.openDetailPage(context, documentBlock);

// Using AppRouter
AppRouter.openBlockDetailPage(context, documentBlock);
```

### Opening a Document Edit Page

```dart
// Using BlockRegistry (recommended)
final updatedBlock = await BlockRegistry.openEditPage(context, documentBlock);

// Using AppRouter
final updatedBlock = await AppRouter.openBlockEditPage(context, documentBlock);
```

### Creating a Document Card

```dart
// Using BlockRegistry (recommended)
final card = BlockRegistry.createCard(documentBlock);

// Direct instantiation
final card = DocumentCard(block: documentBlock);
```

## Related Files

- `lib/blocks/common/block_registry.dart` - Block type registry
- `lib/blocks/common/block_type_ids.dart` - Block type ID constants
- `lib/core/models/block_model.dart` - Block data model
- `lib/core/routing/app_router.dart` - Application router
