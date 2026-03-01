//
//  ContentView.swift
//  MarkdownViewer
//
//  Created by Matthias Zenger on 01/03/2026.
//  Copyright © 2026 Matthias Zenger. All rights reserved.
//  
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import SwiftUI
import MarkdownKit

struct ContentView: View {
  let content = ExtendedMarkdownParser.standard.parse("""
    # Critical Document Title
    
    ## Summary
    
    Lorem ipsum dolor sit amet, **consectetur adipiscing** elit.
    Aliquam non risus in massa ornare lacinia. Etiam at ullamcorper
    ligula. Mauris et orci ut lectus convallis euismod. _Mauris_
    vitae purus congue, finibus tellus nec, lacinia felis.
    Etiam eget lectus quis leo tincidunt venenatis. Duis iaculis
    tristique tempor. _Maecenas vestibulum_ vehicula dui.
    
    ## Considering More Options
    
    Nullam gravida `suscipit placerat`. Vivamus gravida fermentum
    magna vitae condimentum. Interdum et **malesuada fames** ac ante
    ipsum primis in faucibus.
    
    1. This is the first item
    2. This is the second item
    3. This is the third item
    
    Cras laoreet tellus dolor, ac `suscipit augue` molestie a.
    Integer efficitur odio massa, in dictum arcu dictum in.
    Aliquam dapibus congue malesuada. Vestibulum dignissim
    mauris id ipsum volutpat, in dignissim nisi luctus.
    Praesent scelerisque nisi non porttitor dictum. Etiam
    finibus ac libero at rhoncus.
    
    ## Final Remarks
    
    Nunc at dignissim lectus. Integer ligula velit, ullamcorper
    id rutrum vel, iaculis aliquet quam. Praesent congue viverra
    lorem vel faucibus.
    
    > Cras nibh ex, lobortis a tincidunt vel, cursus a dolor.
    > Proin accumsan a risus in venenatis. Etiam eleifend, nisi
    > in auctor tristique, felis risus sodales nibh, eu sodales
    > nunc diam ut sapien.
    
    ## Last But Not Least
    
    Pellentesque ac lectus aliquam, efficitur lacus eu, efficitur justo.
    
    ```scheme
    (define foo 12)
    (define (bar n)
      (if (> n 2) 12 "hello world))
    ```
    
    **Aenean libero nunc**, elementum at justo congue, tristique tincidunt
    lorem. Donec ultrices ante mi, vehicula euismod neque egestas quis.
    Vestibulum vitae ex ut tellus auctor mattis. Aenean eget ornare
    arcu. Lorem ipsum dolor sit amet, consectetur adipiscing elit.
    
    - Morbi ut dui laoreet, euismod libero sed, tincidunt mi. Proin
      pellentesque tellus augue, vel volutpat nulla euismod sed.
        1. Sub-item 1
        2. Sub-item 2
        3. Sub-item 3
    
    - Cras scelerisque ac turpis consequat vulputate. Quisque
      pellentesque mi a imperdiet lobortis. Nulla nec pretium dui.
    
    - Phasellus dolor magna, feugiat et dapibus sed, sodales a eros.
      Aliquam eget sem non nisl viverra placerat sagittis eget tellus.
    
    **Maecenas viverra**, justo nec finibus iaculis, diam turpis malesuada
    nulla, et pharetra nisi diam id nisi. Nam nunc purus, condimentum
    vitae risus tempor, gravida faucibus dolor. Fusce facilisis nisi
    erat, et cursus justo dignissim sed.
    """)
  
  var body: some View {
    MarkdownText(text: self.content)
      .padding()
  }
}
