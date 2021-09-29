// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: camel_case_types

import 'dart:typed_data';

import 'package:objectbox/flatbuffers/flat_buffers.dart' as fb;
import 'package:objectbox/internal.dart'; // generated code can access "internal" functionality
import 'package:bluebubbles/objectbox.g.dart';
import 'package:objectbox_flutter_libs/objectbox_flutter_libs.dart';

import 'repository/models/io/attachment.dart';
import 'repository/models/io/chat.dart';
import 'repository/models/io/fcm_data.dart';
import 'repository/models/io/handle.dart';
import 'repository/models/io/join_tables.dart';
import 'repository/models/io/message.dart';
import 'repository/models/io/scheduled.dart';
import 'repository/models/io/theme_entry.dart';
import 'repository/models/io/theme_object.dart';

export 'package:objectbox/objectbox.dart'; // so that callers only have to import this file

final _entities = <ModelEntity>[
  ModelEntity(
      id: const IdUid(1, 2065429213543838585),
      name: 'Attachment',
      lastPropertyId: const IdUid(16, 396659320299238462),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 1511554263230297197),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 2178477183992316459),
            name: 'originalROWID',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(3, 895699641082029197),
            name: 'guid',
            type: 9,
            flags: 2080,
            indexId: const IdUid(1, 1274831956298930522)),
        ModelProperty(
            id: const IdUid(4, 6047065591027683672),
            name: 'uti',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(5, 8856072667843358452),
            name: 'mimeType',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(6, 2957720185959973011),
            name: 'transferState',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(7, 2217746424870068461),
            name: 'isOutgoing',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(8, 5943814485048944977),
            name: 'transferName',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(9, 2227654525168892418),
            name: 'totalBytes',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(10, 226618350909080419),
            name: 'isSticker',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(11, 7216531465575414151),
            name: 'hideAttachment',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(12, 8776591297555015451),
            name: 'blurhash',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(13, 171869175523313868),
            name: 'height',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(14, 2450795986531805384),
            name: 'width',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(15, 5516087858141459065),
            name: 'bytes',
            type: 23,
            flags: 0),
        ModelProperty(
            id: const IdUid(16, 396659320299238462),
            name: 'webUrl',
            type: 9,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(2, 1619417403499629985),
      name: 'AttachmentMessageJoin',
      lastPropertyId: const IdUid(3, 6032584536718919119),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 977456607049558352),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 2275379924137725049),
            name: 'attachmentId',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(3, 6032584536718919119),
            name: 'messageId',
            type: 6,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(3, 9017250848141753702),
      name: 'Chat',
      lastPropertyId: const IdUid(19, 4234470006262207812),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 297833828287439140),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 8252364803444354563),
            name: 'originalROWID',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(3, 318412581013308394),
            name: 'guid',
            type: 9,
            flags: 2080,
            indexId: const IdUid(2, 4712841847590882583)),
        ModelProperty(
            id: const IdUid(4, 4143511131199296878),
            name: 'style',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(5, 9099706644901956287),
            name: 'chatIdentifier',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(6, 9117376896883192460),
            name: 'isArchived',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(7, 172817608355620424),
            name: 'isFiltered',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(8, 2937507201037513710),
            name: 'muteType',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(9, 3354772670242853270),
            name: 'muteArgs',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(10, 3734639758158862923),
            name: 'isPinned',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(11, 2937716363156975856),
            name: 'hasUnreadMessage',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(12, 526293286661780207),
            name: 'latestMessageDate',
            type: 10,
            flags: 0),
        ModelProperty(
            id: const IdUid(13, 4983193271800913860),
            name: 'latestMessageText',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(14, 130925169208448361),
            name: 'fakeLatestMessageText',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(15, 4266631519717388837),
            name: 'title',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(16, 1181486482872028222),
            name: 'displayName',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(17, 8308083337629235136),
            name: 'fakeParticipants',
            type: 30,
            flags: 0),
        ModelProperty(
            id: const IdUid(18, 3666111733726849006),
            name: 'customAvatarPath',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(19, 4234470006262207812),
            name: 'pinIndex',
            type: 6,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(4, 4450451951397945314),
      name: 'ChatHandleJoin',
      lastPropertyId: const IdUid(3, 8224006478743498888),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 7725198227526963956),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 4236934751716676271),
            name: 'chatId',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(3, 8224006478743498888),
            name: 'handleId',
            type: 6,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(5, 1700370751061310153),
      name: 'ChatMessageJoin',
      lastPropertyId: const IdUid(3, 4510870919779209192),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 7392117204304535224),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 5590979280237537790),
            name: 'chatId',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(3, 4510870919779209192),
            name: 'messageId',
            type: 6,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(6, 5390756932993878582),
      name: 'FCMData',
      lastPropertyId: const IdUid(7, 4724783625435560776),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 843767696595301490),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 4393840145875077709),
            name: 'projectID',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(3, 7264245173656870052),
            name: 'storageBucket',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(4, 3998672972942379984),
            name: 'apiKey',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(5, 3295687739104688136),
            name: 'firebaseURL',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(6, 8856592728926530171),
            name: 'clientID',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(7, 4724783625435560776),
            name: 'applicationID',
            type: 9,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(7, 1716592500251888002),
      name: 'Handle',
      lastPropertyId: const IdUid(7, 549408491521049277),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 683096758365457558),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 191994702917313644),
            name: 'originalROWID',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(3, 2544513926695389102),
            name: 'address',
            type: 9,
            flags: 2080,
            indexId: const IdUid(3, 9132680703832217528)),
        ModelProperty(
            id: const IdUid(4, 8884526609844353946),
            name: 'country',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(5, 3522974353771163433),
            name: 'color',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(6, 57094839621772204),
            name: 'defaultPhone',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(7, 549408491521049277),
            name: 'uncanonicalizedId',
            type: 9,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(8, 7018417362319461469),
      name: 'Message',
      lastPropertyId: const IdUid(36, 861137718943970360),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 8075530627827069587),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 614139107975861462),
            name: 'originalROWID',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(3, 4854433937459051257),
            name: 'guid',
            type: 9,
            flags: 2080,
            indexId: const IdUid(4, 1267669174868830776)),
        ModelProperty(
            id: const IdUid(4, 5895852794473158582),
            name: 'handleId',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(5, 3012867958425492030),
            name: 'otherHandle',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(6, 7948534483488402365),
            name: 'text',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(7, 7283017531024613481),
            name: 'subject',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(8, 6884032144126638879),
            name: 'country',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(9, 6176853844548763600),
            name: 'dateCreated',
            type: 10,
            flags: 0),
        ModelProperty(
            id: const IdUid(10, 9009878668681532753),
            name: 'dateRead',
            type: 10,
            flags: 0),
        ModelProperty(
            id: const IdUid(11, 7709208038424465489),
            name: 'dateDelivered',
            type: 10,
            flags: 0),
        ModelProperty(
            id: const IdUid(12, 3701890428713468427),
            name: 'isFromMe',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(13, 735091670169932122),
            name: 'isDelayed',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(14, 3235490937430157681),
            name: 'isAutoReply',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(15, 8126854405033462697),
            name: 'isSystemMessage',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(16, 82657294837234349),
            name: 'isServiceMessage',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(17, 8117526523647192200),
            name: 'isForward',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(18, 8413228078295213488),
            name: 'isArchived',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(19, 6626097234365517692),
            name: 'hasDdResults',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(20, 939052079357746566),
            name: 'cacheRoomnames',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(21, 3171806281750931518),
            name: 'isAudioMessage',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(22, 4464802064429422611),
            name: 'datePlayed',
            type: 10,
            flags: 0),
        ModelProperty(
            id: const IdUid(23, 5542585324402061600),
            name: 'itemType',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(24, 572939669859263693),
            name: 'groupTitle',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(25, 3185617998247778963),
            name: 'groupActionType',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(26, 769751664576031863),
            name: 'isExpired',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(27, 4077882089992206144),
            name: 'balloonBundleId',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(28, 7238968990385881383),
            name: 'associatedMessageGuid',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(29, 2316337434845256835),
            name: 'associatedMessageType',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(30, 3331740086129339824),
            name: 'expressiveSendStyleId',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(31, 4741144250901643688),
            name: 'timeExpressiveSendStyleId',
            type: 10,
            flags: 0),
        ModelProperty(
            id: const IdUid(32, 1646799728535719055),
            name: 'hasAttachments',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(33, 2482744653836740926),
            name: 'hasReactions',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(34, 3558704390717166171),
            name: 'dateDeleted',
            type: 10,
            flags: 0),
        ModelProperty(
            id: const IdUid(35, 6156393125011218685),
            name: 'bigEmoji',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(36, 861137718943970360),
            name: 'error',
            type: 6,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(9, 2687525031757751054),
      name: 'ScheduledMessage',
      lastPropertyId: const IdUid(5, 7323923293952799044),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 4613854641642738901),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 5956431335972854454),
            name: 'chatGuid',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(3, 8252934173466443273),
            name: 'message',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(4, 7658149783933949012),
            name: 'epochTime',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(5, 7323923293952799044),
            name: 'completed',
            type: 1,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(10, 7380334062783734091),
      name: 'ThemeEntry',
      lastPropertyId: const IdUid(6, 205399809771216750),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 3364349183457626105),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 378260260370164099),
            name: 'themeId',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(3, 1711484628702995090),
            name: 'name',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(4, 5820153989252425651),
            name: 'isFont',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(5, 357044983311472123),
            name: 'fontSize',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(6, 205399809771216750),
            name: 'dbColor',
            type: 9,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(11, 1550674322389882817),
      name: 'ThemeObject',
      lastPropertyId: const IdUid(7, 63810393639568631),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 115725376021487478),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 8802290647274083834),
            name: 'name',
            type: 9,
            flags: 2080,
            indexId: const IdUid(5, 9084358340755218005)),
        ModelProperty(
            id: const IdUid(3, 5487740941825196608),
            name: 'selectedLightTheme',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(4, 2406258303326474883),
            name: 'selectedDarkTheme',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(5, 245348312617052981),
            name: 'gradientBg',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(6, 3858153704624052397),
            name: 'previousLightTheme',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(7, 63810393639568631),
            name: 'previousDarkTheme',
            type: 1,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(12, 3483028772414651169),
      name: 'ThemeValueJoin',
      lastPropertyId: const IdUid(3, 1439376349402210172),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 5203631054946486128),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 2649653758394363860),
            name: 'themeId',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(3, 1439376349402210172),
            name: 'themeValueId',
            type: 6,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[])
];

/// Open an ObjectBox store with the model declared in this file.
Future<Store> openStore(
        {String? directory,
        int? maxDBSizeInKB,
        int? fileMode,
        int? maxReaders,
        bool queriesCaseSensitiveDefault = true,
        String? macosApplicationGroup}) async =>
    Store(getObjectBoxModel(),
        directory: directory ?? (await defaultStoreDirectory()).path,
        maxDBSizeInKB: maxDBSizeInKB,
        fileMode: fileMode,
        maxReaders: maxReaders,
        queriesCaseSensitiveDefault: queriesCaseSensitiveDefault,
        macosApplicationGroup: macosApplicationGroup);

/// ObjectBox model definition, pass it to [Store] - Store(getObjectBoxModel())
ModelDefinition getObjectBoxModel() {
  final model = ModelInfo(
      entities: _entities,
      lastEntityId: const IdUid(12, 3483028772414651169),
      lastIndexId: const IdUid(5, 9084358340755218005),
      lastRelationId: const IdUid(0, 0),
      lastSequenceId: const IdUid(0, 0),
      retiredEntityUids: const [],
      retiredIndexUids: const [],
      retiredPropertyUids: const [],
      retiredRelationUids: const [],
      modelVersion: 5,
      modelVersionParserMinimum: 5,
      version: 1);

  final bindings = <Type, EntityDefinition>{
    Attachment: EntityDefinition<Attachment>(
        model: _entities[0],
        toOneRelations: (Attachment object) => [],
        toManyRelations: (Attachment object) => {},
        getId: (Attachment object) => object.id,
        setId: (Attachment object, int id) {
          object.id = id;
        },
        objectToFB: (Attachment object, fb.Builder fbb) {
          final guidOffset =
              object.guid == null ? null : fbb.writeString(object.guid!);
          final utiOffset =
              object.uti == null ? null : fbb.writeString(object.uti!);
          final mimeTypeOffset = object.mimeType == null
              ? null
              : fbb.writeString(object.mimeType!);
          final transferStateOffset = object.transferState == null
              ? null
              : fbb.writeString(object.transferState!);
          final transferNameOffset = object.transferName == null
              ? null
              : fbb.writeString(object.transferName!);
          final blurhashOffset = object.blurhash == null
              ? null
              : fbb.writeString(object.blurhash!);
          final bytesOffset =
              object.bytes == null ? null : fbb.writeListInt8(object.bytes!);
          final webUrlOffset =
              object.webUrl == null ? null : fbb.writeString(object.webUrl!);
          fbb.startTable(17);
          fbb.addInt64(0, object.id ?? 0);
          fbb.addInt64(1, object.originalROWID);
          fbb.addOffset(2, guidOffset);
          fbb.addOffset(3, utiOffset);
          fbb.addOffset(4, mimeTypeOffset);
          fbb.addOffset(5, transferStateOffset);
          fbb.addBool(6, object.isOutgoing);
          fbb.addOffset(7, transferNameOffset);
          fbb.addInt64(8, object.totalBytes);
          fbb.addBool(9, object.isSticker);
          fbb.addBool(10, object.hideAttachment);
          fbb.addOffset(11, blurhashOffset);
          fbb.addInt64(12, object.height);
          fbb.addInt64(13, object.width);
          fbb.addOffset(14, bytesOffset);
          fbb.addOffset(15, webUrlOffset);
          fbb.finish(fbb.endTable());
          return object.id ?? 0;
        },
        objectFromFB: (Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);
          final bytesValue = const fb.ListReader<int>(fb.Int8Reader())
              .vTableGetNullable(buffer, rootOffset, 32);
          final object = Attachment(
              id: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 4),
              originalROWID: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 6),
              guid: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 8),
              uti: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 10),
              mimeType: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 12),
              transferState: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 14),
              isOutgoing: const fb.BoolReader()
                  .vTableGetNullable(buffer, rootOffset, 16),
              transferName: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 18),
              totalBytes: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 20),
              isSticker: const fb.BoolReader()
                  .vTableGetNullable(buffer, rootOffset, 22),
              hideAttachment: const fb.BoolReader()
                  .vTableGetNullable(buffer, rootOffset, 24),
              blurhash: const fb.StringReader().vTableGetNullable(buffer, rootOffset, 26),
              height: const fb.Int64Reader().vTableGetNullable(buffer, rootOffset, 28),
              width: const fb.Int64Reader().vTableGetNullable(buffer, rootOffset, 30),
              bytes: bytesValue == null ? null : Uint8List.fromList(bytesValue),
              webUrl: const fb.StringReader().vTableGetNullable(buffer, rootOffset, 34));

          return object;
        }),
    AttachmentMessageJoin: EntityDefinition<AttachmentMessageJoin>(
        model: _entities[1],
        toOneRelations: (AttachmentMessageJoin object) => [],
        toManyRelations: (AttachmentMessageJoin object) => {},
        getId: (AttachmentMessageJoin object) => object.id,
        setId: (AttachmentMessageJoin object, int id) {
          object.id = id;
        },
        objectToFB: (AttachmentMessageJoin object, fb.Builder fbb) {
          fbb.startTable(4);
          fbb.addInt64(0, object.id ?? 0);
          fbb.addInt64(1, object.attachmentId);
          fbb.addInt64(2, object.messageId);
          fbb.finish(fbb.endTable());
          return object.id ?? 0;
        },
        objectFromFB: (Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);

          final object = AttachmentMessageJoin(
              attachmentId:
                  const fb.Int64Reader().vTableGet(buffer, rootOffset, 6, 0),
              messageId:
                  const fb.Int64Reader().vTableGet(buffer, rootOffset, 8, 0))
            ..id =
                const fb.Int64Reader().vTableGetNullable(buffer, rootOffset, 4);

          return object;
        }),
    Chat: EntityDefinition<Chat>(
        model: _entities[2],
        toOneRelations: (Chat object) => [],
        toManyRelations: (Chat object) => {},
        getId: (Chat object) => object.id,
        setId: (Chat object, int id) {
          object.id = id;
        },
        objectToFB: (Chat object, fb.Builder fbb) {
          final guidOffset =
              object.guid == null ? null : fbb.writeString(object.guid!);
          final chatIdentifierOffset = object.chatIdentifier == null
              ? null
              : fbb.writeString(object.chatIdentifier!);
          final muteTypeOffset = object.muteType == null
              ? null
              : fbb.writeString(object.muteType!);
          final muteArgsOffset = object.muteArgs == null
              ? null
              : fbb.writeString(object.muteArgs!);
          final latestMessageTextOffset = object.latestMessageText == null
              ? null
              : fbb.writeString(object.latestMessageText!);
          final fakeLatestMessageTextOffset =
              object.fakeLatestMessageText == null
                  ? null
                  : fbb.writeString(object.fakeLatestMessageText!);
          final titleOffset =
              object.title == null ? null : fbb.writeString(object.title!);
          final displayNameOffset = object.displayName == null
              ? null
              : fbb.writeString(object.displayName!);
          final fakeParticipantsOffset = fbb.writeList(object.fakeParticipants
              .map(fbb.writeString)
              .toList(growable: false));
          final customAvatarPathOffset = object.customAvatarPath == null
              ? null
              : fbb.writeString(object.customAvatarPath!);
          fbb.startTable(20);
          fbb.addInt64(0, object.id ?? 0);
          fbb.addInt64(1, object.originalROWID);
          fbb.addOffset(2, guidOffset);
          fbb.addInt64(3, object.style);
          fbb.addOffset(4, chatIdentifierOffset);
          fbb.addBool(5, object.isArchived);
          fbb.addBool(6, object.isFiltered);
          fbb.addOffset(7, muteTypeOffset);
          fbb.addOffset(8, muteArgsOffset);
          fbb.addBool(9, object.isPinned);
          fbb.addBool(10, object.hasUnreadMessage);
          fbb.addInt64(11, object.latestMessageDate?.millisecondsSinceEpoch);
          fbb.addOffset(12, latestMessageTextOffset);
          fbb.addOffset(13, fakeLatestMessageTextOffset);
          fbb.addOffset(14, titleOffset);
          fbb.addOffset(15, displayNameOffset);
          fbb.addOffset(16, fakeParticipantsOffset);
          fbb.addOffset(17, customAvatarPathOffset);
          fbb.addInt64(18, object.pinIndex);
          fbb.finish(fbb.endTable());
          return object.id ?? 0;
        },
        objectFromFB: (Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);
          final latestMessageDateValue =
              const fb.Int64Reader().vTableGetNullable(buffer, rootOffset, 26);
          final object = Chat(
              id: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 4),
              originalROWID: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 6),
              guid: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 8),
              style: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 10),
              chatIdentifier: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 12),
              isArchived: const fb.BoolReader()
                  .vTableGetNullable(buffer, rootOffset, 14),
              isFiltered: const fb.BoolReader()
                  .vTableGetNullable(buffer, rootOffset, 16),
              isPinned: const fb.BoolReader()
                  .vTableGetNullable(buffer, rootOffset, 22),
              muteType: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 18),
              muteArgs: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 20),
              hasUnreadMessage: const fb.BoolReader()
                  .vTableGetNullable(buffer, rootOffset, 24),
              displayName:
                  const fb.StringReader().vTableGetNullable(buffer, rootOffset, 34),
              fakeParticipants: const fb.ListReader<String>(fb.StringReader(), lazy: false).vTableGet(buffer, rootOffset, 36, []),
              latestMessageDate: latestMessageDateValue == null ? null : DateTime.fromMillisecondsSinceEpoch(latestMessageDateValue),
              latestMessageText: const fb.StringReader().vTableGetNullable(buffer, rootOffset, 28),
              fakeLatestMessageText: const fb.StringReader().vTableGetNullable(buffer, rootOffset, 30))
            ..title = const fb.StringReader()
                .vTableGetNullable(buffer, rootOffset, 32)
            ..customAvatarPath = const fb.StringReader()
                .vTableGetNullable(buffer, rootOffset, 38)
            ..pinIndex = const fb.Int64Reader().vTableGetNullable(buffer, rootOffset, 40);

          return object;
        }),
    ChatHandleJoin: EntityDefinition<ChatHandleJoin>(
        model: _entities[3],
        toOneRelations: (ChatHandleJoin object) => [],
        toManyRelations: (ChatHandleJoin object) => {},
        getId: (ChatHandleJoin object) => object.id,
        setId: (ChatHandleJoin object, int id) {
          object.id = id;
        },
        objectToFB: (ChatHandleJoin object, fb.Builder fbb) {
          fbb.startTable(4);
          fbb.addInt64(0, object.id ?? 0);
          fbb.addInt64(1, object.chatId);
          fbb.addInt64(2, object.handleId);
          fbb.finish(fbb.endTable());
          return object.id ?? 0;
        },
        objectFromFB: (Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);

          final object = ChatHandleJoin(
              chatId:
                  const fb.Int64Reader().vTableGet(buffer, rootOffset, 6, 0),
              handleId:
                  const fb.Int64Reader().vTableGet(buffer, rootOffset, 8, 0))
            ..id =
                const fb.Int64Reader().vTableGetNullable(buffer, rootOffset, 4);

          return object;
        }),
    ChatMessageJoin: EntityDefinition<ChatMessageJoin>(
        model: _entities[4],
        toOneRelations: (ChatMessageJoin object) => [],
        toManyRelations: (ChatMessageJoin object) => {},
        getId: (ChatMessageJoin object) => object.id,
        setId: (ChatMessageJoin object, int id) {
          object.id = id;
        },
        objectToFB: (ChatMessageJoin object, fb.Builder fbb) {
          fbb.startTable(4);
          fbb.addInt64(0, object.id ?? 0);
          fbb.addInt64(1, object.chatId);
          fbb.addInt64(2, object.messageId);
          fbb.finish(fbb.endTable());
          return object.id ?? 0;
        },
        objectFromFB: (Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);

          final object = ChatMessageJoin(
              chatId:
                  const fb.Int64Reader().vTableGet(buffer, rootOffset, 6, 0),
              messageId:
                  const fb.Int64Reader().vTableGet(buffer, rootOffset, 8, 0))
            ..id =
                const fb.Int64Reader().vTableGetNullable(buffer, rootOffset, 4);

          return object;
        }),
    FCMData: EntityDefinition<FCMData>(
        model: _entities[5],
        toOneRelations: (FCMData object) => [],
        toManyRelations: (FCMData object) => {},
        getId: (FCMData object) => object.id,
        setId: (FCMData object, int id) {
          object.id = id;
        },
        objectToFB: (FCMData object, fb.Builder fbb) {
          final projectIDOffset = object.projectID == null
              ? null
              : fbb.writeString(object.projectID!);
          final storageBucketOffset = object.storageBucket == null
              ? null
              : fbb.writeString(object.storageBucket!);
          final apiKeyOffset =
              object.apiKey == null ? null : fbb.writeString(object.apiKey!);
          final firebaseURLOffset = object.firebaseURL == null
              ? null
              : fbb.writeString(object.firebaseURL!);
          final clientIDOffset = object.clientID == null
              ? null
              : fbb.writeString(object.clientID!);
          final applicationIDOffset = object.applicationID == null
              ? null
              : fbb.writeString(object.applicationID!);
          fbb.startTable(8);
          fbb.addInt64(0, object.id ?? 0);
          fbb.addOffset(1, projectIDOffset);
          fbb.addOffset(2, storageBucketOffset);
          fbb.addOffset(3, apiKeyOffset);
          fbb.addOffset(4, firebaseURLOffset);
          fbb.addOffset(5, clientIDOffset);
          fbb.addOffset(6, applicationIDOffset);
          fbb.finish(fbb.endTable());
          return object.id ?? 0;
        },
        objectFromFB: (Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);

          final object = FCMData(
              id: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 4),
              projectID: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 6),
              storageBucket: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 8),
              apiKey: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 10),
              firebaseURL: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 12),
              clientID: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 14),
              applicationID: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 16));

          return object;
        }),
    Handle: EntityDefinition<Handle>(
        model: _entities[6],
        toOneRelations: (Handle object) => [],
        toManyRelations: (Handle object) => {},
        getId: (Handle object) => object.id,
        setId: (Handle object, int id) {
          object.id = id;
        },
        objectToFB: (Handle object, fb.Builder fbb) {
          final addressOffset = fbb.writeString(object.address);
          final countryOffset =
              object.country == null ? null : fbb.writeString(object.country!);
          final colorOffset =
              object.color == null ? null : fbb.writeString(object.color!);
          final defaultPhoneOffset = object.defaultPhone == null
              ? null
              : fbb.writeString(object.defaultPhone!);
          final uncanonicalizedIdOffset = object.uncanonicalizedId == null
              ? null
              : fbb.writeString(object.uncanonicalizedId!);
          fbb.startTable(8);
          fbb.addInt64(0, object.id ?? 0);
          fbb.addInt64(1, object.originalROWID);
          fbb.addOffset(2, addressOffset);
          fbb.addOffset(3, countryOffset);
          fbb.addOffset(4, colorOffset);
          fbb.addOffset(5, defaultPhoneOffset);
          fbb.addOffset(6, uncanonicalizedIdOffset);
          fbb.finish(fbb.endTable());
          return object.id ?? 0;
        },
        objectFromFB: (Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);

          final object = Handle(
              id: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 4),
              originalROWID: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 6),
              address:
                  const fb.StringReader().vTableGet(buffer, rootOffset, 8, ''),
              country: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 10),
              defaultPhone: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 14),
              uncanonicalizedId: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 16))
            ..color = const fb.StringReader()
                .vTableGetNullable(buffer, rootOffset, 12);

          return object;
        }),
    Message: EntityDefinition<Message>(
        model: _entities[7],
        toOneRelations: (Message object) => [],
        toManyRelations: (Message object) => {},
        getId: (Message object) => object.id,
        setId: (Message object, int id) {
          object.id = id;
        },
        objectToFB: (Message object, fb.Builder fbb) {
          final guidOffset =
              object.guid == null ? null : fbb.writeString(object.guid!);
          final textOffset =
              object.text == null ? null : fbb.writeString(object.text!);
          final subjectOffset =
              object.subject == null ? null : fbb.writeString(object.subject!);
          final countryOffset =
              object.country == null ? null : fbb.writeString(object.country!);
          final cacheRoomnamesOffset = object.cacheRoomnames == null
              ? null
              : fbb.writeString(object.cacheRoomnames!);
          final groupTitleOffset = object.groupTitle == null
              ? null
              : fbb.writeString(object.groupTitle!);
          final balloonBundleIdOffset = object.balloonBundleId == null
              ? null
              : fbb.writeString(object.balloonBundleId!);
          final associatedMessageGuidOffset =
              object.associatedMessageGuid == null
                  ? null
                  : fbb.writeString(object.associatedMessageGuid!);
          final associatedMessageTypeOffset =
              object.associatedMessageType == null
                  ? null
                  : fbb.writeString(object.associatedMessageType!);
          final expressiveSendStyleIdOffset =
              object.expressiveSendStyleId == null
                  ? null
                  : fbb.writeString(object.expressiveSendStyleId!);
          fbb.startTable(37);
          fbb.addInt64(0, object.id ?? 0);
          fbb.addInt64(1, object.originalROWID);
          fbb.addOffset(2, guidOffset);
          fbb.addInt64(3, object.handleId);
          fbb.addInt64(4, object.otherHandle);
          fbb.addOffset(5, textOffset);
          fbb.addOffset(6, subjectOffset);
          fbb.addOffset(7, countryOffset);
          fbb.addInt64(8, object.dateCreated?.millisecondsSinceEpoch);
          fbb.addInt64(9, object.dateRead?.millisecondsSinceEpoch);
          fbb.addInt64(10, object.dateDelivered?.millisecondsSinceEpoch);
          fbb.addBool(11, object.isFromMe);
          fbb.addBool(12, object.isDelayed);
          fbb.addBool(13, object.isAutoReply);
          fbb.addBool(14, object.isSystemMessage);
          fbb.addBool(15, object.isServiceMessage);
          fbb.addBool(16, object.isForward);
          fbb.addBool(17, object.isArchived);
          fbb.addBool(18, object.hasDdResults);
          fbb.addOffset(19, cacheRoomnamesOffset);
          fbb.addBool(20, object.isAudioMessage);
          fbb.addInt64(21, object.datePlayed?.millisecondsSinceEpoch);
          fbb.addInt64(22, object.itemType);
          fbb.addOffset(23, groupTitleOffset);
          fbb.addInt64(24, object.groupActionType);
          fbb.addBool(25, object.isExpired);
          fbb.addOffset(26, balloonBundleIdOffset);
          fbb.addOffset(27, associatedMessageGuidOffset);
          fbb.addOffset(28, associatedMessageTypeOffset);
          fbb.addOffset(29, expressiveSendStyleIdOffset);
          fbb.addInt64(
              30, object.timeExpressiveSendStyleId?.millisecondsSinceEpoch);
          fbb.addBool(31, object.hasAttachments);
          fbb.addBool(32, object.hasReactions);
          fbb.addInt64(33, object.dateDeleted?.millisecondsSinceEpoch);
          fbb.addBool(34, object.bigEmoji);
          fbb.addInt64(35, object.error);
          fbb.finish(fbb.endTable());
          return object.id ?? 0;
        },
        objectFromFB: (Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);
          final dateCreatedValue =
              const fb.Int64Reader().vTableGetNullable(buffer, rootOffset, 20);
          final dateReadValue =
              const fb.Int64Reader().vTableGetNullable(buffer, rootOffset, 22);
          final dateDeliveredValue =
              const fb.Int64Reader().vTableGetNullable(buffer, rootOffset, 24);
          final datePlayedValue =
              const fb.Int64Reader().vTableGetNullable(buffer, rootOffset, 46);
          final timeExpressiveSendStyleIdValue =
              const fb.Int64Reader().vTableGetNullable(buffer, rootOffset, 64);
          final dateDeletedValue =
              const fb.Int64Reader().vTableGetNullable(buffer, rootOffset, 70);
          final object = Message(
              id: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 4),
              originalROWID: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 6),
              guid: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 8),
              handleId: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 10),
              otherHandle: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 12),
              text: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 14),
              subject: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 16),
              country: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 18),
              dateCreated: dateCreatedValue == null
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(dateCreatedValue),
              dateRead: dateReadValue == null
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(dateReadValue),
              dateDelivered: dateDeliveredValue == null
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(dateDeliveredValue),
              isFromMe:
                  const fb.BoolReader().vTableGetNullable(buffer, rootOffset, 26),
              isDelayed: const fb.BoolReader().vTableGetNullable(buffer, rootOffset, 28),
              isAutoReply: const fb.BoolReader().vTableGetNullable(buffer, rootOffset, 30),
              isSystemMessage: const fb.BoolReader().vTableGetNullable(buffer, rootOffset, 32),
              isServiceMessage: const fb.BoolReader().vTableGetNullable(buffer, rootOffset, 34),
              isForward: const fb.BoolReader().vTableGetNullable(buffer, rootOffset, 36),
              isArchived: const fb.BoolReader().vTableGetNullable(buffer, rootOffset, 38),
              hasDdResults: const fb.BoolReader().vTableGetNullable(buffer, rootOffset, 40),
              cacheRoomnames: const fb.StringReader().vTableGetNullable(buffer, rootOffset, 42),
              isAudioMessage: const fb.BoolReader().vTableGetNullable(buffer, rootOffset, 44),
              datePlayed: datePlayedValue == null ? null : DateTime.fromMillisecondsSinceEpoch(datePlayedValue),
              itemType: const fb.Int64Reader().vTableGetNullable(buffer, rootOffset, 48),
              groupTitle: const fb.StringReader().vTableGetNullable(buffer, rootOffset, 50),
              groupActionType: const fb.Int64Reader().vTableGetNullable(buffer, rootOffset, 52),
              isExpired: const fb.BoolReader().vTableGetNullable(buffer, rootOffset, 54),
              balloonBundleId: const fb.StringReader().vTableGetNullable(buffer, rootOffset, 56),
              associatedMessageGuid: const fb.StringReader().vTableGetNullable(buffer, rootOffset, 58),
              associatedMessageType: const fb.StringReader().vTableGetNullable(buffer, rootOffset, 60),
              expressiveSendStyleId: const fb.StringReader().vTableGetNullable(buffer, rootOffset, 62),
              timeExpressiveSendStyleId: timeExpressiveSendStyleIdValue == null ? null : DateTime.fromMillisecondsSinceEpoch(timeExpressiveSendStyleIdValue),
              hasAttachments: const fb.BoolReader().vTableGet(buffer, rootOffset, 66, false),
              hasReactions: const fb.BoolReader().vTableGet(buffer, rootOffset, 68, false),
              dateDeleted: dateDeletedValue == null ? null : DateTime.fromMillisecondsSinceEpoch(dateDeletedValue))
            ..bigEmoji =
                const fb.BoolReader().vTableGetNullable(buffer, rootOffset, 72)
            ..error = const fb.Int64Reader().vTableGet(buffer, rootOffset, 74, 0);

          return object;
        }),
    ScheduledMessage: EntityDefinition<ScheduledMessage>(
        model: _entities[8],
        toOneRelations: (ScheduledMessage object) => [],
        toManyRelations: (ScheduledMessage object) => {},
        getId: (ScheduledMessage object) => object.id,
        setId: (ScheduledMessage object, int id) {
          object.id = id;
        },
        objectToFB: (ScheduledMessage object, fb.Builder fbb) {
          final chatGuidOffset = object.chatGuid == null
              ? null
              : fbb.writeString(object.chatGuid!);
          final messageOffset =
              object.message == null ? null : fbb.writeString(object.message!);
          fbb.startTable(6);
          fbb.addInt64(0, object.id ?? 0);
          fbb.addOffset(1, chatGuidOffset);
          fbb.addOffset(2, messageOffset);
          fbb.addInt64(3, object.epochTime);
          fbb.addBool(4, object.completed);
          fbb.finish(fbb.endTable());
          return object.id ?? 0;
        },
        objectFromFB: (Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);

          final object = ScheduledMessage(
              id: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 4),
              chatGuid: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 6),
              message: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 8),
              epochTime: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 10),
              completed: const fb.BoolReader()
                  .vTableGetNullable(buffer, rootOffset, 12));

          return object;
        }),
    ThemeEntry: EntityDefinition<ThemeEntry>(
        model: _entities[9],
        toOneRelations: (ThemeEntry object) => [],
        toManyRelations: (ThemeEntry object) => {},
        getId: (ThemeEntry object) => object.id,
        setId: (ThemeEntry object, int id) {
          object.id = id;
        },
        objectToFB: (ThemeEntry object, fb.Builder fbb) {
          final nameOffset =
              object.name == null ? null : fbb.writeString(object.name!);
          final dbColorOffset =
              object.dbColor == null ? null : fbb.writeString(object.dbColor!);
          fbb.startTable(7);
          fbb.addInt64(0, object.id ?? 0);
          fbb.addInt64(1, object.themeId);
          fbb.addOffset(2, nameOffset);
          fbb.addBool(3, object.isFont);
          fbb.addInt64(4, object.fontSize);
          fbb.addOffset(5, dbColorOffset);
          fbb.finish(fbb.endTable());
          return object.id ?? 0;
        },
        objectFromFB: (Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);

          final object = ThemeEntry(
              id: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 4),
              themeId: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 6),
              name: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 8),
              isFont: const fb.BoolReader()
                  .vTableGetNullable(buffer, rootOffset, 10),
              fontSize: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 12))
            ..dbColor = const fb.StringReader()
                .vTableGetNullable(buffer, rootOffset, 14);

          return object;
        }),
    ThemeObject: EntityDefinition<ThemeObject>(
        model: _entities[10],
        toOneRelations: (ThemeObject object) => [],
        toManyRelations: (ThemeObject object) => {},
        getId: (ThemeObject object) => object.id,
        setId: (ThemeObject object, int id) {
          object.id = id;
        },
        objectToFB: (ThemeObject object, fb.Builder fbb) {
          final nameOffset =
              object.name == null ? null : fbb.writeString(object.name!);
          fbb.startTable(8);
          fbb.addInt64(0, object.id ?? 0);
          fbb.addOffset(1, nameOffset);
          fbb.addBool(2, object.selectedLightTheme);
          fbb.addBool(3, object.selectedDarkTheme);
          fbb.addBool(4, object.gradientBg);
          fbb.addBool(5, object.previousLightTheme);
          fbb.addBool(6, object.previousDarkTheme);
          fbb.finish(fbb.endTable());
          return object.id ?? 0;
        },
        objectFromFB: (Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);

          final object = ThemeObject(
              id: const fb.Int64Reader()
                  .vTableGetNullable(buffer, rootOffset, 4),
              name: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 6),
              selectedLightTheme:
                  const fb.BoolReader().vTableGet(buffer, rootOffset, 8, false),
              selectedDarkTheme: const fb.BoolReader()
                  .vTableGet(buffer, rootOffset, 10, false),
              gradientBg: const fb.BoolReader()
                  .vTableGet(buffer, rootOffset, 12, false),
              previousLightTheme: const fb.BoolReader()
                  .vTableGet(buffer, rootOffset, 14, false),
              previousDarkTheme: const fb.BoolReader()
                  .vTableGet(buffer, rootOffset, 16, false));

          return object;
        }),
    ThemeValueJoin: EntityDefinition<ThemeValueJoin>(
        model: _entities[11],
        toOneRelations: (ThemeValueJoin object) => [],
        toManyRelations: (ThemeValueJoin object) => {},
        getId: (ThemeValueJoin object) => object.id,
        setId: (ThemeValueJoin object, int id) {
          object.id = id;
        },
        objectToFB: (ThemeValueJoin object, fb.Builder fbb) {
          fbb.startTable(4);
          fbb.addInt64(0, object.id ?? 0);
          fbb.addInt64(1, object.themeId);
          fbb.addInt64(2, object.themeValueId);
          fbb.finish(fbb.endTable());
          return object.id ?? 0;
        },
        objectFromFB: (Store store, ByteData fbData) {
          final buffer = fb.BufferContext(fbData);
          final rootOffset = buffer.derefObject(0);

          final object = ThemeValueJoin(
              themeId:
                  const fb.Int64Reader().vTableGet(buffer, rootOffset, 6, 0),
              themeValueId:
                  const fb.Int64Reader().vTableGet(buffer, rootOffset, 8, 0))
            ..id =
                const fb.Int64Reader().vTableGetNullable(buffer, rootOffset, 4);

          return object;
        })
  };

  return ModelDefinition(model, bindings);
}

/// [Attachment] entity fields to define ObjectBox queries.
class Attachment_ {
  /// see [Attachment.id]
  static final id =
      QueryIntegerProperty<Attachment>(_entities[0].properties[0]);

  /// see [Attachment.originalROWID]
  static final originalROWID =
      QueryIntegerProperty<Attachment>(_entities[0].properties[1]);

  /// see [Attachment.guid]
  static final guid =
      QueryStringProperty<Attachment>(_entities[0].properties[2]);

  /// see [Attachment.uti]
  static final uti =
      QueryStringProperty<Attachment>(_entities[0].properties[3]);

  /// see [Attachment.mimeType]
  static final mimeType =
      QueryStringProperty<Attachment>(_entities[0].properties[4]);

  /// see [Attachment.transferState]
  static final transferState =
      QueryStringProperty<Attachment>(_entities[0].properties[5]);

  /// see [Attachment.isOutgoing]
  static final isOutgoing =
      QueryBooleanProperty<Attachment>(_entities[0].properties[6]);

  /// see [Attachment.transferName]
  static final transferName =
      QueryStringProperty<Attachment>(_entities[0].properties[7]);

  /// see [Attachment.totalBytes]
  static final totalBytes =
      QueryIntegerProperty<Attachment>(_entities[0].properties[8]);

  /// see [Attachment.isSticker]
  static final isSticker =
      QueryBooleanProperty<Attachment>(_entities[0].properties[9]);

  /// see [Attachment.hideAttachment]
  static final hideAttachment =
      QueryBooleanProperty<Attachment>(_entities[0].properties[10]);

  /// see [Attachment.blurhash]
  static final blurhash =
      QueryStringProperty<Attachment>(_entities[0].properties[11]);

  /// see [Attachment.height]
  static final height =
      QueryIntegerProperty<Attachment>(_entities[0].properties[12]);

  /// see [Attachment.width]
  static final width =
      QueryIntegerProperty<Attachment>(_entities[0].properties[13]);

  /// see [Attachment.bytes]
  static final bytes =
      QueryByteVectorProperty<Attachment>(_entities[0].properties[14]);

  /// see [Attachment.webUrl]
  static final webUrl =
      QueryStringProperty<Attachment>(_entities[0].properties[15]);
}

/// [AttachmentMessageJoin] entity fields to define ObjectBox queries.
class AttachmentMessageJoin_ {
  /// see [AttachmentMessageJoin.id]
  static final id =
      QueryIntegerProperty<AttachmentMessageJoin>(_entities[1].properties[0]);

  /// see [AttachmentMessageJoin.attachmentId]
  static final attachmentId =
      QueryIntegerProperty<AttachmentMessageJoin>(_entities[1].properties[1]);

  /// see [AttachmentMessageJoin.messageId]
  static final messageId =
      QueryIntegerProperty<AttachmentMessageJoin>(_entities[1].properties[2]);
}

/// [Chat] entity fields to define ObjectBox queries.
class Chat_ {
  /// see [Chat.id]
  static final id = QueryIntegerProperty<Chat>(_entities[2].properties[0]);

  /// see [Chat.originalROWID]
  static final originalROWID =
      QueryIntegerProperty<Chat>(_entities[2].properties[1]);

  /// see [Chat.guid]
  static final guid = QueryStringProperty<Chat>(_entities[2].properties[2]);

  /// see [Chat.style]
  static final style = QueryIntegerProperty<Chat>(_entities[2].properties[3]);

  /// see [Chat.chatIdentifier]
  static final chatIdentifier =
      QueryStringProperty<Chat>(_entities[2].properties[4]);

  /// see [Chat.isArchived]
  static final isArchived =
      QueryBooleanProperty<Chat>(_entities[2].properties[5]);

  /// see [Chat.isFiltered]
  static final isFiltered =
      QueryBooleanProperty<Chat>(_entities[2].properties[6]);

  /// see [Chat.muteType]
  static final muteType = QueryStringProperty<Chat>(_entities[2].properties[7]);

  /// see [Chat.muteArgs]
  static final muteArgs = QueryStringProperty<Chat>(_entities[2].properties[8]);

  /// see [Chat.isPinned]
  static final isPinned =
      QueryBooleanProperty<Chat>(_entities[2].properties[9]);

  /// see [Chat.hasUnreadMessage]
  static final hasUnreadMessage =
      QueryBooleanProperty<Chat>(_entities[2].properties[10]);

  /// see [Chat.latestMessageDate]
  static final latestMessageDate =
      QueryIntegerProperty<Chat>(_entities[2].properties[11]);

  /// see [Chat.latestMessageText]
  static final latestMessageText =
      QueryStringProperty<Chat>(_entities[2].properties[12]);

  /// see [Chat.fakeLatestMessageText]
  static final fakeLatestMessageText =
      QueryStringProperty<Chat>(_entities[2].properties[13]);

  /// see [Chat.title]
  static final title = QueryStringProperty<Chat>(_entities[2].properties[14]);

  /// see [Chat.displayName]
  static final displayName =
      QueryStringProperty<Chat>(_entities[2].properties[15]);

  /// see [Chat.fakeParticipants]
  static final fakeParticipants =
      QueryStringVectorProperty<Chat>(_entities[2].properties[16]);

  /// see [Chat.customAvatarPath]
  static final customAvatarPath =
      QueryStringProperty<Chat>(_entities[2].properties[17]);

  /// see [Chat.pinIndex]
  static final pinIndex =
      QueryIntegerProperty<Chat>(_entities[2].properties[18]);
}

/// [ChatHandleJoin] entity fields to define ObjectBox queries.
class ChatHandleJoin_ {
  /// see [ChatHandleJoin.id]
  static final id =
      QueryIntegerProperty<ChatHandleJoin>(_entities[3].properties[0]);

  /// see [ChatHandleJoin.chatId]
  static final chatId =
      QueryIntegerProperty<ChatHandleJoin>(_entities[3].properties[1]);

  /// see [ChatHandleJoin.handleId]
  static final handleId =
      QueryIntegerProperty<ChatHandleJoin>(_entities[3].properties[2]);
}

/// [ChatMessageJoin] entity fields to define ObjectBox queries.
class ChatMessageJoin_ {
  /// see [ChatMessageJoin.id]
  static final id =
      QueryIntegerProperty<ChatMessageJoin>(_entities[4].properties[0]);

  /// see [ChatMessageJoin.chatId]
  static final chatId =
      QueryIntegerProperty<ChatMessageJoin>(_entities[4].properties[1]);

  /// see [ChatMessageJoin.messageId]
  static final messageId =
      QueryIntegerProperty<ChatMessageJoin>(_entities[4].properties[2]);
}

/// [FCMData] entity fields to define ObjectBox queries.
class FCMData_ {
  /// see [FCMData.id]
  static final id = QueryIntegerProperty<FCMData>(_entities[5].properties[0]);

  /// see [FCMData.projectID]
  static final projectID =
      QueryStringProperty<FCMData>(_entities[5].properties[1]);

  /// see [FCMData.storageBucket]
  static final storageBucket =
      QueryStringProperty<FCMData>(_entities[5].properties[2]);

  /// see [FCMData.apiKey]
  static final apiKey =
      QueryStringProperty<FCMData>(_entities[5].properties[3]);

  /// see [FCMData.firebaseURL]
  static final firebaseURL =
      QueryStringProperty<FCMData>(_entities[5].properties[4]);

  /// see [FCMData.clientID]
  static final clientID =
      QueryStringProperty<FCMData>(_entities[5].properties[5]);

  /// see [FCMData.applicationID]
  static final applicationID =
      QueryStringProperty<FCMData>(_entities[5].properties[6]);
}

/// [Handle] entity fields to define ObjectBox queries.
class Handle_ {
  /// see [Handle.id]
  static final id = QueryIntegerProperty<Handle>(_entities[6].properties[0]);

  /// see [Handle.originalROWID]
  static final originalROWID =
      QueryIntegerProperty<Handle>(_entities[6].properties[1]);

  /// see [Handle.address]
  static final address =
      QueryStringProperty<Handle>(_entities[6].properties[2]);

  /// see [Handle.country]
  static final country =
      QueryStringProperty<Handle>(_entities[6].properties[3]);

  /// see [Handle.color]
  static final color = QueryStringProperty<Handle>(_entities[6].properties[4]);

  /// see [Handle.defaultPhone]
  static final defaultPhone =
      QueryStringProperty<Handle>(_entities[6].properties[5]);

  /// see [Handle.uncanonicalizedId]
  static final uncanonicalizedId =
      QueryStringProperty<Handle>(_entities[6].properties[6]);
}

/// [Message] entity fields to define ObjectBox queries.
class Message_ {
  /// see [Message.id]
  static final id = QueryIntegerProperty<Message>(_entities[7].properties[0]);

  /// see [Message.originalROWID]
  static final originalROWID =
      QueryIntegerProperty<Message>(_entities[7].properties[1]);

  /// see [Message.guid]
  static final guid = QueryStringProperty<Message>(_entities[7].properties[2]);

  /// see [Message.handleId]
  static final handleId =
      QueryIntegerProperty<Message>(_entities[7].properties[3]);

  /// see [Message.otherHandle]
  static final otherHandle =
      QueryIntegerProperty<Message>(_entities[7].properties[4]);

  /// see [Message.text]
  static final text = QueryStringProperty<Message>(_entities[7].properties[5]);

  /// see [Message.subject]
  static final subject =
      QueryStringProperty<Message>(_entities[7].properties[6]);

  /// see [Message.country]
  static final country =
      QueryStringProperty<Message>(_entities[7].properties[7]);

  /// see [Message.dateCreated]
  static final dateCreated =
      QueryIntegerProperty<Message>(_entities[7].properties[8]);

  /// see [Message.dateRead]
  static final dateRead =
      QueryIntegerProperty<Message>(_entities[7].properties[9]);

  /// see [Message.dateDelivered]
  static final dateDelivered =
      QueryIntegerProperty<Message>(_entities[7].properties[10]);

  /// see [Message.isFromMe]
  static final isFromMe =
      QueryBooleanProperty<Message>(_entities[7].properties[11]);

  /// see [Message.isDelayed]
  static final isDelayed =
      QueryBooleanProperty<Message>(_entities[7].properties[12]);

  /// see [Message.isAutoReply]
  static final isAutoReply =
      QueryBooleanProperty<Message>(_entities[7].properties[13]);

  /// see [Message.isSystemMessage]
  static final isSystemMessage =
      QueryBooleanProperty<Message>(_entities[7].properties[14]);

  /// see [Message.isServiceMessage]
  static final isServiceMessage =
      QueryBooleanProperty<Message>(_entities[7].properties[15]);

  /// see [Message.isForward]
  static final isForward =
      QueryBooleanProperty<Message>(_entities[7].properties[16]);

  /// see [Message.isArchived]
  static final isArchived =
      QueryBooleanProperty<Message>(_entities[7].properties[17]);

  /// see [Message.hasDdResults]
  static final hasDdResults =
      QueryBooleanProperty<Message>(_entities[7].properties[18]);

  /// see [Message.cacheRoomnames]
  static final cacheRoomnames =
      QueryStringProperty<Message>(_entities[7].properties[19]);

  /// see [Message.isAudioMessage]
  static final isAudioMessage =
      QueryBooleanProperty<Message>(_entities[7].properties[20]);

  /// see [Message.datePlayed]
  static final datePlayed =
      QueryIntegerProperty<Message>(_entities[7].properties[21]);

  /// see [Message.itemType]
  static final itemType =
      QueryIntegerProperty<Message>(_entities[7].properties[22]);

  /// see [Message.groupTitle]
  static final groupTitle =
      QueryStringProperty<Message>(_entities[7].properties[23]);

  /// see [Message.groupActionType]
  static final groupActionType =
      QueryIntegerProperty<Message>(_entities[7].properties[24]);

  /// see [Message.isExpired]
  static final isExpired =
      QueryBooleanProperty<Message>(_entities[7].properties[25]);

  /// see [Message.balloonBundleId]
  static final balloonBundleId =
      QueryStringProperty<Message>(_entities[7].properties[26]);

  /// see [Message.associatedMessageGuid]
  static final associatedMessageGuid =
      QueryStringProperty<Message>(_entities[7].properties[27]);

  /// see [Message.associatedMessageType]
  static final associatedMessageType =
      QueryStringProperty<Message>(_entities[7].properties[28]);

  /// see [Message.expressiveSendStyleId]
  static final expressiveSendStyleId =
      QueryStringProperty<Message>(_entities[7].properties[29]);

  /// see [Message.timeExpressiveSendStyleId]
  static final timeExpressiveSendStyleId =
      QueryIntegerProperty<Message>(_entities[7].properties[30]);

  /// see [Message.hasAttachments]
  static final hasAttachments =
      QueryBooleanProperty<Message>(_entities[7].properties[31]);

  /// see [Message.hasReactions]
  static final hasReactions =
      QueryBooleanProperty<Message>(_entities[7].properties[32]);

  /// see [Message.dateDeleted]
  static final dateDeleted =
      QueryIntegerProperty<Message>(_entities[7].properties[33]);

  /// see [Message.bigEmoji]
  static final bigEmoji =
      QueryBooleanProperty<Message>(_entities[7].properties[34]);

  /// see [Message.error]
  static final error =
      QueryIntegerProperty<Message>(_entities[7].properties[35]);
}

/// [ScheduledMessage] entity fields to define ObjectBox queries.
class ScheduledMessage_ {
  /// see [ScheduledMessage.id]
  static final id =
      QueryIntegerProperty<ScheduledMessage>(_entities[8].properties[0]);

  /// see [ScheduledMessage.chatGuid]
  static final chatGuid =
      QueryStringProperty<ScheduledMessage>(_entities[8].properties[1]);

  /// see [ScheduledMessage.message]
  static final message =
      QueryStringProperty<ScheduledMessage>(_entities[8].properties[2]);

  /// see [ScheduledMessage.epochTime]
  static final epochTime =
      QueryIntegerProperty<ScheduledMessage>(_entities[8].properties[3]);

  /// see [ScheduledMessage.completed]
  static final completed =
      QueryBooleanProperty<ScheduledMessage>(_entities[8].properties[4]);
}

/// [ThemeEntry] entity fields to define ObjectBox queries.
class ThemeEntry_ {
  /// see [ThemeEntry.id]
  static final id =
      QueryIntegerProperty<ThemeEntry>(_entities[9].properties[0]);

  /// see [ThemeEntry.themeId]
  static final themeId =
      QueryIntegerProperty<ThemeEntry>(_entities[9].properties[1]);

  /// see [ThemeEntry.name]
  static final name =
      QueryStringProperty<ThemeEntry>(_entities[9].properties[2]);

  /// see [ThemeEntry.isFont]
  static final isFont =
      QueryBooleanProperty<ThemeEntry>(_entities[9].properties[3]);

  /// see [ThemeEntry.fontSize]
  static final fontSize =
      QueryIntegerProperty<ThemeEntry>(_entities[9].properties[4]);

  /// see [ThemeEntry.dbColor]
  static final dbColor =
      QueryStringProperty<ThemeEntry>(_entities[9].properties[5]);
}

/// [ThemeObject] entity fields to define ObjectBox queries.
class ThemeObject_ {
  /// see [ThemeObject.id]
  static final id =
      QueryIntegerProperty<ThemeObject>(_entities[10].properties[0]);

  /// see [ThemeObject.name]
  static final name =
      QueryStringProperty<ThemeObject>(_entities[10].properties[1]);

  /// see [ThemeObject.selectedLightTheme]
  static final selectedLightTheme =
      QueryBooleanProperty<ThemeObject>(_entities[10].properties[2]);

  /// see [ThemeObject.selectedDarkTheme]
  static final selectedDarkTheme =
      QueryBooleanProperty<ThemeObject>(_entities[10].properties[3]);

  /// see [ThemeObject.gradientBg]
  static final gradientBg =
      QueryBooleanProperty<ThemeObject>(_entities[10].properties[4]);

  /// see [ThemeObject.previousLightTheme]
  static final previousLightTheme =
      QueryBooleanProperty<ThemeObject>(_entities[10].properties[5]);

  /// see [ThemeObject.previousDarkTheme]
  static final previousDarkTheme =
      QueryBooleanProperty<ThemeObject>(_entities[10].properties[6]);
}

/// [ThemeValueJoin] entity fields to define ObjectBox queries.
class ThemeValueJoin_ {
  /// see [ThemeValueJoin.id]
  static final id =
      QueryIntegerProperty<ThemeValueJoin>(_entities[11].properties[0]);

  /// see [ThemeValueJoin.themeId]
  static final themeId =
      QueryIntegerProperty<ThemeValueJoin>(_entities[11].properties[1]);

  /// see [ThemeValueJoin.themeValueId]
  static final themeValueId =
      QueryIntegerProperty<ThemeValueJoin>(_entities[11].properties[2]);
}
