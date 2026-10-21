import '../../features/properties/domain/property.dart';
import '../../features/viewings/domain/viewing.dart';

/// Общее in-memory состояние mock-репозиториев.
/// Заменяется реальным API, когда контракт бэкенда доступен.
class MockStore {
  MockStore.seed() {
    final now = DateTime.now();

    String demoPhoto(int i) => 'assets/properties/interior-$i.jpg';

    properties.addAll([
      Property(
        id: 'p1',
        title: 'ЖК «Северное сияние»',
        address: 'ул. Мангилик Ел, 24',
        city: 'Астана',
        price: 48000000,
        rooms: 2,
        area: 64,
        photoUrl: demoPhoto(1),
        description:
            'Светлая квартира с панорамными окнами на левый берег. '
            'Свежий ремонт, встроенная кухня, закрытый двор с подземным паркингом. '
            'Рядом школа, набережная и ТРЦ.',
      ),
      Property(
        id: 'p2',
        title: 'ЖК «Highvill»',
        address: 'пр. Аль-Фараби, 77/8',
        city: 'Алматы',
        price: 85000000,
        rooms: 3,
        area: 92,
        photoUrl: demoPhoto(2),
        description:
            'Просторная трёшка в доме бизнес-класса у подножия гор. '
            'Два санузла, гардеробная, вид на горы из гостиной. '
            'Охраняемая территория, детский сад во дворе.',
      ),
      Property(
        id: 'p3',
        title: 'ЖК «Prime Plaza»',
        address: 'ул. Достык, 132',
        city: 'Астана',
        price: 32000000,
        rooms: 1,
        area: 42,
        photoUrl: demoPhoto(3),
        description:
            'Компактная студия с функциональной планировкой — хороший вариант '
            'для аренды или первого жилья. Мебель частично остаётся.',
      ),
      Property(
        id: 'p4',
        title: 'ЖК «Арман»',
        address: 'ул. Ауэзова, 14',
        city: 'Алматы',
        price: 61000000,
        rooms: 2,
        area: 58,
        photoUrl: demoPhoto(4),
        description:
            'Квартира в тихом центре, потолки 3,1 м, кирпичный дом. '
            'Тихие соседи, развитая инфраструктура: рынок, метро, парк в 5 минутах.',
      ),
      Property(
        id: 'p5',
        title: 'ЖК «Emerald Quarter»',
        address: 'ул. Сауран, 5',
        city: 'Астана',
        price: 74000000,
        rooms: 3,
        area: 84,
        photoUrl: demoPhoto(5),
        description:
            'Новый дом с консьержем и дизайнерским лобби. '
            'Панорамное остекление, тёплый пол, кухня по индивидуальному проекту.',
      ),
      Property(
        id: 'p6',
        title: 'ЖК «Достык Residences»',
        address: 'ул. Женис, 66',
        city: 'Астана',
        price: 26500000,
        rooms: 1,
        area: 38,
        photoUrl: demoPhoto(6),
        description:
            'Уютная однушка рядом с Экспо. Сдаётся с техникой, '
            'подходит для жизни и для сдачи в аренду.',
      ),
    ]);

    // Демо-бронирования для покупателя buyer@demo.kz.
    final buyerBookedSlots = [
      DateTime(now.year, now.month, now.day + 1, 15),
      DateTime(now.year, now.month, now.day + 2, 11),
      DateTime(now.year, now.month, now.day - 1, 17, 30),
    ];
    viewings.add(
      Viewing(
        id: 'v1',
        propertyId: 'p1',
        propertyTitle: properties[0].title,
        propertyAddress: '${properties[0].city}, ${properties[0].address}',
        propertyPhotoUrl: properties[0].photoUrl,
        startsAtUtc: buyerBookedSlots[0].toUtc(),
        status: ViewingStatus.pending,
        buyerId: 'u-buyer',
        buyerName: 'Айдар Сериков',
        buyerPhone: '+7 701 123 45 67',
      ),
    );
    viewings.add(
      Viewing(
        id: 'v2',
        propertyId: 'p2',
        propertyTitle: properties[1].title,
        propertyAddress: '${properties[1].city}, ${properties[1].address}',
        propertyPhotoUrl: properties[1].photoUrl,
        startsAtUtc: buyerBookedSlots[1].toUtc(),
        status: ViewingStatus.confirmed,
        buyerId: 'u-buyer',
        buyerName: 'Айдар Сериков',
        buyerPhone: '+7 701 123 45 67',
      ),
    );
    viewings.add(
      Viewing(
        id: 'v3',
        propertyId: 'p3',
        propertyTitle: properties[2].title,
        propertyAddress: '${properties[2].city}, ${properties[2].address}',
        propertyPhotoUrl: properties[2].photoUrl,
        startsAtUtc: buyerBookedSlots[2].toUtc(),
        status: ViewingStatus.cancelled,
        buyerId: 'u-buyer',
        buyerName: 'Айдар Сериков',
        buyerPhone: '+7 701 123 45 67',
      ),
    );
  }

  final List<Property> properties = [];
  final List<Viewing> viewings = [];

  int _propertySeq = 7;
  int _viewingSeq = 100;

  String nextPropertyId() => 'p${_propertySeq++}';
  String nextViewingId() => 'v${_viewingSeq++}';
}
