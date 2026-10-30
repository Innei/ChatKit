import ChatKitCore
import Testing

private func groups(_ count: Int) -> [String] { (0..<count).map { "e\($0)" } }

@Test func opensOnTheLatestPage() {
  var window = CKHistoryWindow()
  let v1 = window.update(groups: groups(120))
  #expect(v1 == 70)
  #expect(window.hasEarlier)
  #expect(!window.isPreparing)
}

@Test func liveAppendsKeepTheBoundary() {
  var window = CKHistoryWindow()
  _ = window.update(groups: groups(120))
  let v2 = window.update(groups: groups(130))
  #expect(v2 == 70)
}

@Test func anEarlierPageCommitsOnlyWhenPreparedAndStill() {
  var window = CKHistoryWindow()
  let all = groups(120)
  _ = window.update(groups: all)
  let v3 = window.requestEarlier()
  #expect(v3)
  let v4 = window.requestEarlier()
  #expect(!v4)
  let v5 = window.page(groups: all)
  #expect(v5 == Array(all[20..<70]))
  let v6 = window.commit(groups: all, pageRows: ["r1", "r2"], scrollMoving: false)
  #expect(!v6)
  window.markPrepared(["r1", "r2"])
  let v7 = window.commit(groups: all, pageRows: ["r1", "r2"], scrollMoving: true)
  #expect(!v7)
  let v8 = window.commit(groups: all, pageRows: ["r1", "r2"], scrollMoving: false)
  #expect(v8)
  let v9 = window.update(groups: all)
  #expect(v9 == 20)
  #expect(window.hasPaged)
  #expect(!window.isPreparing)
}

@Test func aWidthChangeDropsPreparedRows() {
  var window = CKHistoryWindow()
  let all = groups(120)
  _ = window.update(groups: all)
  _ = window.requestEarlier()
  window.widthChanged(400)
  window.markPrepared(["r1"])
  window.widthChanged(420)
  #expect(!window.isPrepared("r1"))
  let v10 = window.commit(groups: all, pageRows: ["r1"], scrollMoving: false)
  #expect(!v10)
}

@Test func theFirstPageReachesTheStart() {
  var window = CKHistoryWindow(pageSize: 50)
  let all = groups(60)
  _ = window.update(groups: all)
  _ = window.requestEarlier()
  let v11 = window.page(groups: all)
  #expect(v11 == Array(all[0..<10]))
  let v12 = window.commit(groups: all, pageRows: [], scrollMoving: false)
  #expect(v12)
  #expect(!window.hasEarlier)
  let v13 = window.update(groups: all)
  #expect(v13 == 0)
}

@Test func emptyHistoryResets() {
  var window = CKHistoryWindow()
  _ = window.update(groups: groups(120))
  let v14 = window.update(groups: [])
  #expect(v14 == 0)
  #expect(!window.hasEarlier)
  #expect(!window.hasPaged)
}

@Test func prefetchOnlyNearTheTopWhenTheReaderIsBrowsing() {
  #expect(CKHistoryWindow.shouldPrefetch(distanceFromTop: 300, viewport: 600, following: false, finding: false, positioned: true))
  #expect(!CKHistoryWindow.shouldPrefetch(distanceFromTop: 700, viewport: 600, following: false, finding: false, positioned: true))
  #expect(!CKHistoryWindow.shouldPrefetch(distanceFromTop: 300, viewport: 600, following: true, finding: false, positioned: true))
  #expect(!CKHistoryWindow.shouldPrefetch(distanceFromTop: 300, viewport: 600, following: false, finding: true, positioned: true))
  #expect(!CKHistoryWindow.shouldPrefetch(distanceFromTop: 300, viewport: 600, following: false, finding: false, positioned: false))
}
