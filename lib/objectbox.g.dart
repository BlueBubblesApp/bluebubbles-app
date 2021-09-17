// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: camel_case_types

import 'dart:typed_data';

import 'package:objectbox/flatbuffers/flat_buffers.dart' as fb;
import 'package:objectbox/internal.dart'; // generated code can access "internal" functionality
import 'package:objectbox/objectbox.dart';
import 'package:objectbox_flutter_libs/objectbox_flutter_libs.dart';

import 'repository/models/attachment.dart';
import 'repository/models/chat.dart';
import 'repository/models/fcm_data.dart';
import 'repository/models/handle.dart';
import 'repository/models/join_tables.dart';
import 'repository/models/message.dart';
import 'repository/models/scheduled.dart';
import 'repository/models/theme_entry.dart';
import 'repository/models/theme_object.dart';

export 'package:objectbox/objectbox.dart'; // so that callers only have to import this file

final _entities = <ModelEntity>[
  ModelEntity(
      id: const IdUid(1, 5636756020347489224),
      name: 'Attachment',
      lastPropertyId: const IdUid(16, 5401479817248495953),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 8693603267900198095),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 6856548206356608866),
            name: 'originalROWID',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(3, 642423011304918962),
            name: 'guid',
            type: 9,
            flags: 2080,
            indexId: const IdUid(12, 871162635557036689)),
        ModelProperty(
            id: const IdUid(4, 6472398705044253119),
            name: 'uti',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(5, 6468391474044183822),
            name: 'mimeType',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(6, 5217116740256684500),
            name: 'transferState',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(7, 3032125173662237367),
            name: 'isOutgoing',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(8, 2434158114444426785),
            name: 'transferName',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(9, 8831058129101907911),
            name: 'totalBytes',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(10, 6273918102995985372),
            name: 'isSticker',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(11, 3111216942063806968),
            name: 'hideAttachment',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(12, 2962903551193245932),
            name: 'blurhash',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(13, 1679424220585547230),
            name: 'height',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(14, 8600661885396964271),
            name: 'width',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(15, 2179065843947296739),
            name: 'bytes',
            type: 23,
            flags: 0),
        ModelProperty(
            id: const IdUid(16, 5401479817248495953),
            name: 'webUrl',
            type: 9,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(2, 7655897984831475506),
      name: 'Chat',
      lastPropertyId: const IdUid(19, 3876709740745146476),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 1880017237828131464),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 3950164872323877500),
            name: 'originalROWID',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(3, 477879858635570732),
            name: 'guid',
            type: 9,
            flags: 2080,
            indexId: const IdUid(13, 6507016670835863959)),
        ModelProperty(
            id: const IdUid(4, 3516964772281787630),
            name: 'style',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(5, 5857974903220055014),
            name: 'chatIdentifier',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(6, 187914747110257540),
            name: 'isArchived',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(7, 5538068556008948740),
            name: 'isFiltered',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(8, 2734178026575835758),
            name: 'muteType',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(9, 3131349602340664591),
            name: 'muteArgs',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(10, 3340217014115733899),
            name: 'isPinned',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(11, 823994482667699960),
            name: 'hasUnreadMessage',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(12, 2753200985244019342),
            name: 'latestMessageDate',
            type: 10,
            flags: 0),
        ModelProperty(
            id: const IdUid(13, 5261339330459694287),
            name: 'latestMessageText',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(14, 6891050863056339478),
            name: 'fakeLatestMessageText',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(15, 1403686968974488028),
            name: 'title',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(16, 2029479927215016281),
            name: 'displayName',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(17, 2064894493176780814),
            name: 'fakeParticipants',
            type: 30,
            flags: 0),
        ModelProperty(
            id: const IdUid(18, 8329914874449689989),
            name: 'customAvatarPath',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(19, 3876709740745146476),
            name: 'pinIndex',
            type: 6,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(3, 802318764109036539),
      name: 'FCMData',
      lastPropertyId: const IdUid(7, 5843357141260679145),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 9087636751539709632),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 7026222770216548615),
            name: 'projectID',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(3, 6410247068948090782),
            name: 'storageBucket',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(4, 480990701082819338),
            name: 'apiKey',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(5, 7434711874814188466),
            name: 'firebaseURL',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(6, 1147582743268732770),
            name: 'clientID',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(7, 5843357141260679145),
            name: 'applicationID',
            type: 9,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(4, 3978498765598706232),
      name: 'Handle',
      lastPropertyId: const IdUid(7, 7087605193975797253),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 6553229072011226285),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 2947219604619176824),
            name: 'originalROWID',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(3, 7331966002854573867),
            name: 'address',
            type: 9,
            flags: 2080,
            indexId: const IdUid(15, 8376622246943281247)),
        ModelProperty(
            id: const IdUid(4, 2077144733144318968),
            name: 'country',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(5, 2337138172616289428),
            name: 'color',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(6, 6757440411505726564),
            name: 'defaultPhone',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(7, 7087605193975797253),
            name: 'uncanonicalizedId',
            type: 9,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(5, 1777055777990229716),
      name: 'Message',
      lastPropertyId: const IdUid(36, 5371657780578355776),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 4118593632180577377),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 8254377283008156346),
            name: 'originalROWID',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(3, 9106527856567703198),
            name: 'guid',
            type: 9,
            flags: 2080,
            indexId: const IdUid(14, 2451614700084883646)),
        ModelProperty(
            id: const IdUid(4, 8541995138318107705),
            name: 'handleId',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(5, 3336115590719717231),
            name: 'otherHandle',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(6, 2529775584935063506),
            name: 'text',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(7, 7949618411743019721),
            name: 'subject',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(8, 7674950630548191418),
            name: 'country',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(9, 3365058815328818806),
            name: 'dateCreated',
            type: 10,
            flags: 0),
        ModelProperty(
            id: const IdUid(10, 1366181429967713897),
            name: 'dateRead',
            type: 10,
            flags: 0),
        ModelProperty(
            id: const IdUid(11, 1413951679586903049),
            name: 'dateDelivered',
            type: 10,
            flags: 0),
        ModelProperty(
            id: const IdUid(12, 95659294744187119),
            name: 'isFromMe',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(13, 5873235040208188963),
            name: 'isDelayed',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(14, 8896925230382686059),
            name: 'isAutoReply',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(15, 1453581299787112935),
            name: 'isSystemMessage',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(16, 540721464977836031),
            name: 'isServiceMessage',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(17, 2371491005408157265),
            name: 'isForward',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(18, 5909384338604692946),
            name: 'isArchived',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(19, 664712553654229838),
            name: 'hasDdResults',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(20, 3387050565454132845),
            name: 'cacheRoomnames',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(21, 3318185869986092735),
            name: 'isAudioMessage',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(22, 6793113338757674598),
            name: 'datePlayed',
            type: 10,
            flags: 0),
        ModelProperty(
            id: const IdUid(23, 4259716758486724624),
            name: 'itemType',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(24, 3759826866186316290),
            name: 'groupTitle',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(25, 4454745076120261698),
            name: 'groupActionType',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(26, 474244973546807393),
            name: 'isExpired',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(27, 8406884830732966384),
            name: 'balloonBundleId',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(28, 883386380420289365),
            name: 'associatedMessageGuid',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(29, 1778052144631688572),
            name: 'associatedMessageType',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(30, 7497032030707123256),
            name: 'expressiveSendStyleId',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(31, 5867684840297367302),
            name: 'timeExpressiveSendStyleId',
            type: 10,
            flags: 0),
        ModelProperty(
            id: const IdUid(32, 8183755968597629970),
            name: 'hasAttachments',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(33, 4784459657424290264),
            name: 'hasReactions',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(34, 9123100654958526965),
            name: 'dateDeleted',
            type: 10,
            flags: 0),
        ModelProperty(
            id: const IdUid(35, 6685534689277940397),
            name: 'bigEmoji',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(36, 5371657780578355776),
            name: 'error',
            type: 6,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(6, 2946007897443499125),
      name: 'ScheduledMessage',
      lastPropertyId: const IdUid(5, 1896638784156728642),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 1488002543338942429),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 213546286686366952),
            name: 'chatGuid',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(3, 8404120816558502647),
            name: 'message',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(4, 4272968969960624020),
            name: 'epochTime',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(5, 1896638784156728642),
            name: 'completed',
            type: 1,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(7, 1462868055402691409),
      name: 'ThemeEntry',
      lastPropertyId: const IdUid(6, 2250820418310055866),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 5091392742641028323),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 1732548762823851542),
            name: 'themeId',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(3, 8139314960807963395),
            name: 'name',
            type: 9,
            flags: 0),
        ModelProperty(
            id: const IdUid(4, 410044398812148236),
            name: 'isFont',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(5, 80109056724467926),
            name: 'fontSize',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(6, 2250820418310055866),
            name: 'dbColor',
            type: 9,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(8, 7102013928011129368),
      name: 'ThemeObject',
      lastPropertyId: const IdUid(7, 6973085402682640656),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 8031032626144498831),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 1032765298976566553),
            name: 'name',
            type: 9,
            flags: 2080,
            indexId: const IdUid(16, 1397796027232769352)),
        ModelProperty(
            id: const IdUid(3, 1831352951497229583),
            name: 'selectedLightTheme',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(4, 397549370056674545),
            name: 'selectedDarkTheme',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(5, 4950729307887560818),
            name: 'gradientBg',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(6, 8436118668888231789),
            name: 'previousLightTheme',
            type: 1,
            flags: 0),
        ModelProperty(
            id: const IdUid(7, 6973085402682640656),
            name: 'previousDarkTheme',
            type: 1,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(9, 3987535430387190268),
      name: 'AttachmentMessageJoin',
      lastPropertyId: const IdUid(3, 4467860992763339461),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 4037844847967696071),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 9043781543327844759),
            name: 'attachmentId',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(3, 4467860992763339461),
            name: 'messageId',
            type: 6,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(10, 2024015112470640080),
      name: 'ChatHandleJoin',
      lastPropertyId: const IdUid(3, 2047178923387944561),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 3505064794548364728),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 6470650482714001312),
            name: 'chatId',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(3, 2047178923387944561),
            name: 'handleId',
            type: 6,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(11, 3309653850879548047),
      name: 'ChatMessageJoin',
      lastPropertyId: const IdUid(3, 774682362860934880),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 522928070339154591),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 1664142881686886045),
            name: 'chatId',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(3, 774682362860934880),
            name: 'messageId',
            type: 6,
            flags: 0)
      ],
      relations: <ModelRelation>[],
      backlinks: <ModelBacklink>[]),
  ModelEntity(
      id: const IdUid(12, 728205196772171913),
      name: 'ThemeValueJoin',
      lastPropertyId: const IdUid(3, 2366701955689855838),
      flags: 0,
      properties: <ModelProperty>[
        ModelProperty(
            id: const IdUid(1, 8597520343978579088),
            name: 'id',
            type: 6,
            flags: 1),
        ModelProperty(
            id: const IdUid(2, 7823578036522406351),
            name: 'themeId',
            type: 6,
            flags: 0),
        ModelProperty(
            id: const IdUid(3, 2366701955689855838),
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
      lastEntityId: const IdUid(12, 728205196772171913),
      lastIndexId: const IdUid(16, 1397796027232769352),
      lastRelationId: const IdUid(0, 0),
      lastSequenceId: const IdUid(0, 0),
      retiredEntityUids: const [],
      retiredIndexUids: const [
        6178621782339867599,
        1524781639313223952,
        72464332395755262,
        6501593594565047229,
        5723224251525092179,
        7519480210398590301,
        381471371504606275,
        5061151663060002291,
        5624391444535392849,
        1735903661491959140,
        1140861954766729493
      ],
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
    Chat: EntityDefinition<Chat>(
        model: _entities[1],
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
    FCMData: EntityDefinition<FCMData>(
        model: _entities[2],
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
        model: _entities[3],
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
              color: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 12),
              defaultPhone: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 14),
              uncanonicalizedId: const fb.StringReader()
                  .vTableGetNullable(buffer, rootOffset, 16));

          return object;
        }),
    Message: EntityDefinition<Message>(
        model: _entities[4],
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
        model: _entities[5],
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
        model: _entities[6],
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
        model: _entities[7],
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
    AttachmentMessageJoin: EntityDefinition<AttachmentMessageJoin>(
        model: _entities[8],
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
    ChatHandleJoin: EntityDefinition<ChatHandleJoin>(
        model: _entities[9],
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
        model: _entities[10],
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

/// [Chat] entity fields to define ObjectBox queries.
class Chat_ {
  /// see [Chat.id]
  static final id = QueryIntegerProperty<Chat>(_entities[1].properties[0]);

  /// see [Chat.originalROWID]
  static final originalROWID =
      QueryIntegerProperty<Chat>(_entities[1].properties[1]);

  /// see [Chat.guid]
  static final guid = QueryStringProperty<Chat>(_entities[1].properties[2]);

  /// see [Chat.style]
  static final style = QueryIntegerProperty<Chat>(_entities[1].properties[3]);

  /// see [Chat.chatIdentifier]
  static final chatIdentifier =
      QueryStringProperty<Chat>(_entities[1].properties[4]);

  /// see [Chat.isArchived]
  static final isArchived =
      QueryBooleanProperty<Chat>(_entities[1].properties[5]);

  /// see [Chat.isFiltered]
  static final isFiltered =
      QueryBooleanProperty<Chat>(_entities[1].properties[6]);

  /// see [Chat.muteType]
  static final muteType = QueryStringProperty<Chat>(_entities[1].properties[7]);

  /// see [Chat.muteArgs]
  static final muteArgs = QueryStringProperty<Chat>(_entities[1].properties[8]);

  /// see [Chat.isPinned]
  static final isPinned =
      QueryBooleanProperty<Chat>(_entities[1].properties[9]);

  /// see [Chat.hasUnreadMessage]
  static final hasUnreadMessage =
      QueryBooleanProperty<Chat>(_entities[1].properties[10]);

  /// see [Chat.latestMessageDate]
  static final latestMessageDate =
      QueryIntegerProperty<Chat>(_entities[1].properties[11]);

  /// see [Chat.latestMessageText]
  static final latestMessageText =
      QueryStringProperty<Chat>(_entities[1].properties[12]);

  /// see [Chat.fakeLatestMessageText]
  static final fakeLatestMessageText =
      QueryStringProperty<Chat>(_entities[1].properties[13]);

  /// see [Chat.title]
  static final title = QueryStringProperty<Chat>(_entities[1].properties[14]);

  /// see [Chat.displayName]
  static final displayName =
      QueryStringProperty<Chat>(_entities[1].properties[15]);

  /// see [Chat.fakeParticipants]
  static final fakeParticipants =
      QueryStringVectorProperty<Chat>(_entities[1].properties[16]);

  /// see [Chat.customAvatarPath]
  static final customAvatarPath =
      QueryStringProperty<Chat>(_entities[1].properties[17]);

  /// see [Chat.pinIndex]
  static final pinIndex =
      QueryIntegerProperty<Chat>(_entities[1].properties[18]);
}

/// [FCMData] entity fields to define ObjectBox queries.
class FCMData_ {
  /// see [FCMData.id]
  static final id = QueryIntegerProperty<FCMData>(_entities[2].properties[0]);

  /// see [FCMData.projectID]
  static final projectID =
      QueryStringProperty<FCMData>(_entities[2].properties[1]);

  /// see [FCMData.storageBucket]
  static final storageBucket =
      QueryStringProperty<FCMData>(_entities[2].properties[2]);

  /// see [FCMData.apiKey]
  static final apiKey =
      QueryStringProperty<FCMData>(_entities[2].properties[3]);

  /// see [FCMData.firebaseURL]
  static final firebaseURL =
      QueryStringProperty<FCMData>(_entities[2].properties[4]);

  /// see [FCMData.clientID]
  static final clientID =
      QueryStringProperty<FCMData>(_entities[2].properties[5]);

  /// see [FCMData.applicationID]
  static final applicationID =
      QueryStringProperty<FCMData>(_entities[2].properties[6]);
}

/// [Handle] entity fields to define ObjectBox queries.
class Handle_ {
  /// see [Handle.id]
  static final id = QueryIntegerProperty<Handle>(_entities[3].properties[0]);

  /// see [Handle.originalROWID]
  static final originalROWID =
      QueryIntegerProperty<Handle>(_entities[3].properties[1]);

  /// see [Handle.address]
  static final address =
      QueryStringProperty<Handle>(_entities[3].properties[2]);

  /// see [Handle.country]
  static final country =
      QueryStringProperty<Handle>(_entities[3].properties[3]);

  /// see [Handle.color]
  static final color = QueryStringProperty<Handle>(_entities[3].properties[4]);

  /// see [Handle.defaultPhone]
  static final defaultPhone =
      QueryStringProperty<Handle>(_entities[3].properties[5]);

  /// see [Handle.uncanonicalizedId]
  static final uncanonicalizedId =
      QueryStringProperty<Handle>(_entities[3].properties[6]);
}

/// [Message] entity fields to define ObjectBox queries.
class Message_ {
  /// see [Message.id]
  static final id = QueryIntegerProperty<Message>(_entities[4].properties[0]);

  /// see [Message.originalROWID]
  static final originalROWID =
      QueryIntegerProperty<Message>(_entities[4].properties[1]);

  /// see [Message.guid]
  static final guid = QueryStringProperty<Message>(_entities[4].properties[2]);

  /// see [Message.handleId]
  static final handleId =
      QueryIntegerProperty<Message>(_entities[4].properties[3]);

  /// see [Message.otherHandle]
  static final otherHandle =
      QueryIntegerProperty<Message>(_entities[4].properties[4]);

  /// see [Message.text]
  static final text = QueryStringProperty<Message>(_entities[4].properties[5]);

  /// see [Message.subject]
  static final subject =
      QueryStringProperty<Message>(_entities[4].properties[6]);

  /// see [Message.country]
  static final country =
      QueryStringProperty<Message>(_entities[4].properties[7]);

  /// see [Message.dateCreated]
  static final dateCreated =
      QueryIntegerProperty<Message>(_entities[4].properties[8]);

  /// see [Message.dateRead]
  static final dateRead =
      QueryIntegerProperty<Message>(_entities[4].properties[9]);

  /// see [Message.dateDelivered]
  static final dateDelivered =
      QueryIntegerProperty<Message>(_entities[4].properties[10]);

  /// see [Message.isFromMe]
  static final isFromMe =
      QueryBooleanProperty<Message>(_entities[4].properties[11]);

  /// see [Message.isDelayed]
  static final isDelayed =
      QueryBooleanProperty<Message>(_entities[4].properties[12]);

  /// see [Message.isAutoReply]
  static final isAutoReply =
      QueryBooleanProperty<Message>(_entities[4].properties[13]);

  /// see [Message.isSystemMessage]
  static final isSystemMessage =
      QueryBooleanProperty<Message>(_entities[4].properties[14]);

  /// see [Message.isServiceMessage]
  static final isServiceMessage =
      QueryBooleanProperty<Message>(_entities[4].properties[15]);

  /// see [Message.isForward]
  static final isForward =
      QueryBooleanProperty<Message>(_entities[4].properties[16]);

  /// see [Message.isArchived]
  static final isArchived =
      QueryBooleanProperty<Message>(_entities[4].properties[17]);

  /// see [Message.hasDdResults]
  static final hasDdResults =
      QueryBooleanProperty<Message>(_entities[4].properties[18]);

  /// see [Message.cacheRoomnames]
  static final cacheRoomnames =
      QueryStringProperty<Message>(_entities[4].properties[19]);

  /// see [Message.isAudioMessage]
  static final isAudioMessage =
      QueryBooleanProperty<Message>(_entities[4].properties[20]);

  /// see [Message.datePlayed]
  static final datePlayed =
      QueryIntegerProperty<Message>(_entities[4].properties[21]);

  /// see [Message.itemType]
  static final itemType =
      QueryIntegerProperty<Message>(_entities[4].properties[22]);

  /// see [Message.groupTitle]
  static final groupTitle =
      QueryStringProperty<Message>(_entities[4].properties[23]);

  /// see [Message.groupActionType]
  static final groupActionType =
      QueryIntegerProperty<Message>(_entities[4].properties[24]);

  /// see [Message.isExpired]
  static final isExpired =
      QueryBooleanProperty<Message>(_entities[4].properties[25]);

  /// see [Message.balloonBundleId]
  static final balloonBundleId =
      QueryStringProperty<Message>(_entities[4].properties[26]);

  /// see [Message.associatedMessageGuid]
  static final associatedMessageGuid =
      QueryStringProperty<Message>(_entities[4].properties[27]);

  /// see [Message.associatedMessageType]
  static final associatedMessageType =
      QueryStringProperty<Message>(_entities[4].properties[28]);

  /// see [Message.expressiveSendStyleId]
  static final expressiveSendStyleId =
      QueryStringProperty<Message>(_entities[4].properties[29]);

  /// see [Message.timeExpressiveSendStyleId]
  static final timeExpressiveSendStyleId =
      QueryIntegerProperty<Message>(_entities[4].properties[30]);

  /// see [Message.hasAttachments]
  static final hasAttachments =
      QueryBooleanProperty<Message>(_entities[4].properties[31]);

  /// see [Message.hasReactions]
  static final hasReactions =
      QueryBooleanProperty<Message>(_entities[4].properties[32]);

  /// see [Message.dateDeleted]
  static final dateDeleted =
      QueryIntegerProperty<Message>(_entities[4].properties[33]);

  /// see [Message.bigEmoji]
  static final bigEmoji =
      QueryBooleanProperty<Message>(_entities[4].properties[34]);

  /// see [Message.error]
  static final error =
      QueryIntegerProperty<Message>(_entities[4].properties[35]);
}

/// [ScheduledMessage] entity fields to define ObjectBox queries.
class ScheduledMessage_ {
  /// see [ScheduledMessage.id]
  static final id =
      QueryIntegerProperty<ScheduledMessage>(_entities[5].properties[0]);

  /// see [ScheduledMessage.chatGuid]
  static final chatGuid =
      QueryStringProperty<ScheduledMessage>(_entities[5].properties[1]);

  /// see [ScheduledMessage.message]
  static final message =
      QueryStringProperty<ScheduledMessage>(_entities[5].properties[2]);

  /// see [ScheduledMessage.epochTime]
  static final epochTime =
      QueryIntegerProperty<ScheduledMessage>(_entities[5].properties[3]);

  /// see [ScheduledMessage.completed]
  static final completed =
      QueryBooleanProperty<ScheduledMessage>(_entities[5].properties[4]);
}

/// [ThemeEntry] entity fields to define ObjectBox queries.
class ThemeEntry_ {
  /// see [ThemeEntry.id]
  static final id =
      QueryIntegerProperty<ThemeEntry>(_entities[6].properties[0]);

  /// see [ThemeEntry.themeId]
  static final themeId =
      QueryIntegerProperty<ThemeEntry>(_entities[6].properties[1]);

  /// see [ThemeEntry.name]
  static final name =
      QueryStringProperty<ThemeEntry>(_entities[6].properties[2]);

  /// see [ThemeEntry.isFont]
  static final isFont =
      QueryBooleanProperty<ThemeEntry>(_entities[6].properties[3]);

  /// see [ThemeEntry.fontSize]
  static final fontSize =
      QueryIntegerProperty<ThemeEntry>(_entities[6].properties[4]);

  /// see [ThemeEntry.dbColor]
  static final dbColor =
      QueryStringProperty<ThemeEntry>(_entities[6].properties[5]);
}

/// [ThemeObject] entity fields to define ObjectBox queries.
class ThemeObject_ {
  /// see [ThemeObject.id]
  static final id =
      QueryIntegerProperty<ThemeObject>(_entities[7].properties[0]);

  /// see [ThemeObject.name]
  static final name =
      QueryStringProperty<ThemeObject>(_entities[7].properties[1]);

  /// see [ThemeObject.selectedLightTheme]
  static final selectedLightTheme =
      QueryBooleanProperty<ThemeObject>(_entities[7].properties[2]);

  /// see [ThemeObject.selectedDarkTheme]
  static final selectedDarkTheme =
      QueryBooleanProperty<ThemeObject>(_entities[7].properties[3]);

  /// see [ThemeObject.gradientBg]
  static final gradientBg =
      QueryBooleanProperty<ThemeObject>(_entities[7].properties[4]);

  /// see [ThemeObject.previousLightTheme]
  static final previousLightTheme =
      QueryBooleanProperty<ThemeObject>(_entities[7].properties[5]);

  /// see [ThemeObject.previousDarkTheme]
  static final previousDarkTheme =
      QueryBooleanProperty<ThemeObject>(_entities[7].properties[6]);
}

/// [AttachmentMessageJoin] entity fields to define ObjectBox queries.
class AttachmentMessageJoin_ {
  /// see [AttachmentMessageJoin.id]
  static final id =
      QueryIntegerProperty<AttachmentMessageJoin>(_entities[8].properties[0]);

  /// see [AttachmentMessageJoin.attachmentId]
  static final attachmentId =
      QueryIntegerProperty<AttachmentMessageJoin>(_entities[8].properties[1]);

  /// see [AttachmentMessageJoin.messageId]
  static final messageId =
      QueryIntegerProperty<AttachmentMessageJoin>(_entities[8].properties[2]);
}

/// [ChatHandleJoin] entity fields to define ObjectBox queries.
class ChatHandleJoin_ {
  /// see [ChatHandleJoin.id]
  static final id =
      QueryIntegerProperty<ChatHandleJoin>(_entities[9].properties[0]);

  /// see [ChatHandleJoin.chatId]
  static final chatId =
      QueryIntegerProperty<ChatHandleJoin>(_entities[9].properties[1]);

  /// see [ChatHandleJoin.handleId]
  static final handleId =
      QueryIntegerProperty<ChatHandleJoin>(_entities[9].properties[2]);
}

/// [ChatMessageJoin] entity fields to define ObjectBox queries.
class ChatMessageJoin_ {
  /// see [ChatMessageJoin.id]
  static final id =
      QueryIntegerProperty<ChatMessageJoin>(_entities[10].properties[0]);

  /// see [ChatMessageJoin.chatId]
  static final chatId =
      QueryIntegerProperty<ChatMessageJoin>(_entities[10].properties[1]);

  /// see [ChatMessageJoin.messageId]
  static final messageId =
      QueryIntegerProperty<ChatMessageJoin>(_entities[10].properties[2]);
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
