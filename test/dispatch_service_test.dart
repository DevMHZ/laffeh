import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:laffeh/core/di/service_locator.dart';
import 'package:laffeh/features/dispatch/dispatch_inbox_page.dart';
import 'package:mocktail/mocktail.dart';
import 'package:laffeh/features/auth/domain/entities/auth_user.dart';
import 'package:laffeh/features/auth/domain/repositories/auth_repository.dart';
import 'package:laffeh/features/dispatch/dispatch_service.dart';

class FakeAuth extends Mock implements AuthRepository {}

Map<String,dynamic> trip(String id,{String driver='driver-a'})=>{
  'id':id,'driver_id':driver,'trip_name':'Morning round','sender_name':'Dispatcher',
  'company_name':'Company','created_at':'2026-10-02T08:00:00Z','opened_at':null,
};

void main() {
  late FakeAuth auth;
  late StreamController<AuthUser?> sessions;
  late AuthUser? user;
  late Dio dio;
  late DispatchService service;
  setUp(() {
    auth=FakeAuth();user=const AuthUser(id:'driver-a',phone:'+33783719427');
    sessions=StreamController<AuthUser?>.broadcast(sync:true);
    when(()=>auth.currentUser).thenAnswer((_)=>user);
    when(()=>auth.authStateChanges()).thenAnswer((_)=>sessions.stream);
    dio=Dio(BaseOptions(baseUrl:'https://dispatch.test'));
    service=DispatchService(auth,dio,()=>user==null?null:'session-token');
  });
  tearDown(() async {service.dispose();await sessions.close();dio.close();});

  test('sign-in loads inbox using the mobile session',() async {
    final done=Completer<void>();
    dio.interceptors.add(InterceptorsWrapper(onRequest:(request,handler){
      expect(request.headers['Authorization'],'Bearer session-token');
      expect(request.path,'/dispatch/inbox');
      handler.resolve(Response(requestOptions:request,data:{'trips':[trip('one')],'unread_count':1,'has_more':false}));
    }));
    service.addListener(() {if(!service.loading && service.trips.isNotEmpty && !done.isCompleted)done.complete();});
    service.start();await done.future;
    expect(service.unread,1);expect(service.trips.single.company,'Company');
  });

  test('late response cannot leak trips after sign-out',() async {
    final pending=Completer<void>();
    late RequestOptions request;late RequestInterceptorHandler handler;
    dio.interceptors.add(InterceptorsWrapper(onRequest:(r,h){request=r;handler=h;pending.complete();}));
    service.start();await pending.future;
    user=null;sessions.add(null);
    handler.resolve(Response(requestOptions:request,data:{'trips':[trip('private')],'unread_count':1,'has_more':false}));
    await Future<void>.delayed(Duration.zero);
    expect(service.trips,isEmpty);expect(service.unread,0);expect(service.signedIn,false);
  });

  test('late trip download is rejected after account switch',() async {
    final pending=Completer<void>();
    late RequestOptions request;late RequestInterceptorHandler handler;
    dio.interceptors.add(InterceptorsWrapper(onRequest:(r,h){request=r;handler=h;pending.complete();}));
    final fetch=service.fetchTrip('one');
    final check=expectLater(fetch,throwsStateError);
    await pending.future;
    user=const AuthUser(id:'driver-b');
    handler.resolve(Response(requestOptions:request,data:trip('one')));
    await check;
  });

  test('offline refresh preserves the current inbox and exposes retry state',() async {
    service.trips=[ReceivedTrip.fromJson(trip('one'))];
    dio.interceptors.add(InterceptorsWrapper(onRequest:(r,h)=>h.reject(DioException(requestOptions:r,type:DioExceptionType.connectionError))));
    await service.refresh();
    expect(service.trips.single.id,'one');expect(service.error,isNotNull);expect(service.loading,false);
  });

  test('opened acknowledgement never runs for another account',() async {
    var called=false;
    dio.interceptors.add(InterceptorsWrapper(onRequest:(r,h){called=true;h.resolve(Response(requestOptions:r,data:{}));}));
    await service.markOpened(ReceivedTrip.fromJson(trip('one',driver:'other')));
    expect(called,false);
  });

  testWidgets('received trips show company, date and unread state on a phone', (tester) async {
    tester.view.physicalSize=const Size(390,844);
    tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    sl.registerSingleton<DispatchService>(service);
    addTearDown(()=>sl.unregister<DispatchService>());
    dio.interceptors.add(InterceptorsWrapper(onRequest:(r,h)=>h.resolve(Response(requestOptions:r,data:{'trips':[trip('one')],'unread_count':1,'has_more':false}))));
    await tester.pumpWidget(const MaterialApp(home:DispatchInboxPage()));
    await tester.pumpAndSettle();
    expect(find.text('Received trips'),findsOneWidget);
    expect(find.text('Company · Dispatcher'),findsOneWidget);
    expect(find.text('New'),findsOneWidget);
    expect(find.text('Open round'),findsOneWidget);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
